package Padre::Wx::Editor;

use 5.008;
use strict;
use warnings;
use YAML::Tiny                ();
use Time::HiRes               ();
use Padre::Constant           ();
use Padre::Config             ();
use Padre::Feature            ();
use Padre::Util               ();
use Padre::DB                 ();
use Padre::Wx                 ();
use Padre::Wx::FileDropTarget ();
use Padre::Wx::Role::Main     ();
use Padre::Wx::Role::Dwell    ();
use Padre::Logger;

# Allow the use of two different versions of Scintilla
use constant WX_SCINTILLA => Padre::Config::wx_scintilla_ready()
	? 'Wx::ScintillaTextCtrl'
	: 'Wx::StyledTextCtrl';

our $VERSION    = '0.90';
our $COMPATIBLE = '0.89';
our @ISA        = (
	'Padre::Wx::Role::Main',
	'Padre::Wx::Role::Dwell',
	WX_SCINTILLA,
);

use constant {

	# Convenience colour constants
	# NOTE: DO NOT USE "orange" string since it is actually red on win32
	ORANGE => Wx::Colour->new( 255, 165, 0 ),
	RED    => Wx::Colour->new("red"),
	GREEN  => Wx::Colour->new("green"),
	BLUE   => Wx::Colour->new("blue"),

	# Indicators
	INDICATOR_SMART_HIGHLIGHT => 0,
	INDICATOR_WARNING         => 1,
	INDICATOR_ERROR           => 2,
};

# End-Of-Line modes:
# MAC is actually Mac classic.
# MAC OS X and later uses UNIX EOLs
#
# Please note that WIN32 is the API. DO NOT change it to that :)
#
# Initialize variables after loading either Wx::Scintilla or Wx::STC
my %WXEOL = (
	WIN  => Wx::wxSTC_EOL_CRLF,
	MAC  => Wx::wxSTC_EOL_CR,
	UNIX => Wx::wxSTC_EOL_LF,
);

# mapping for mime-type to the style name in the share/styles/default.yml file
# TODO this should be defined in MimeTypes.pm
our %MIME_STYLE = (
	'application/x-perl'     => 'perl',
	'application/x-psgi'     => 'perl',
	'text/x-perlxs'          => 'xs',   # should be in the plugin...
	'text/x-patch'           => 'diff',
	'text/x-makefile'        => 'make',
	'text/x-yaml'            => 'yaml',
	'text/css'               => 'css',
	'application/x-php'      => 'perl', # temporary solution
	'text/x-c'               => 'c',
	'text/x-c++src'          => 'c',
	'text/x-csharp'          => 'c',
	'application/javascript' => 'c',
	'text/x-java-source'     => 'c',
);

my $data;
my $data_name;
my $data_private;





######################################################################
# Constructor and Accessors

sub new {
	my $class  = shift;
	my $parent = shift;

	# NOTE: This hack is only here because the Preferences dialog uses
	# an editor object for their style preview thingy.
	my $main = $parent;
	while ( not $main->isa('Padre::Wx::Main') ) {
		$main = $main->GetParent;
	}

	# Create the underlying Wx object
	my $lock   = $main->lock( 'UPDATE', 'refresh_windowlist' );
	my $self   = $class->SUPER::new($parent);
	my $config = $self->config;

	# This is supposed to be Wx::wxSTC_CP_UTF8
	# and Wx::wxUNICODE or wxUSE_UNICODE should be on
	$self->SetCodePage(65001);

	# Code always lays out left to right
	if ( $self->can('SetLayoutDirection') ) {
		$self->SetLayoutDirection(Wx::wxLayout_LeftToRight);
	}

	# Integration with the rest of Padre
	$self->SetDropTarget( Padre::Wx::FileDropTarget->new($main) );

	# Set the code margins a little larger than the default.
	# This seems to noticably reduce eye strain.
	$self->SetMarginLeft(2);
	$self->SetMarginRight(0);

	# Clear out all the other margins
	$self->SetMarginWidth( 0, 0 );
	$self->SetMarginWidth( 1, 0 );
	$self->SetMarginWidth( 2, 0 );

	# Set the colour scheme for syntax highlight markers
	$self->MarkerDefine(
		Padre::Wx::MarkError(),
		Wx::wxSTC_MARK_SMALLRECT,
		RED,
		RED,
	);
	$self->MarkerDefine(
		Padre::Wx::MarkWarn(),
		Wx::wxSTC_MARK_SMALLRECT,
		ORANGE,
		ORANGE,
	);
	$self->MarkerDefine(
		Padre::Wx::MarkLocation(),
		Wx::wxSTC_MARK_SMALLRECT,
		GREEN,
		GREEN,
	);
	$self->MarkerDefine(
		Padre::Wx::MarkBreakpoint(),
		Wx::wxSTC_MARK_SMALLRECT,
		BLUE,
		BLUE,
	);

	# No more unsafe CTRL-L for you :)
	# CTRL-L or line cut should only work when there is no empty line
	# This prevents the accidental destruction of the clipboard
	$self->CmdKeyClear( ord('L'), Wx::wxSTC_SCMOD_CTRL );

	# Disable CTRL keypad -/+. These seem to emit wrong scan codes
	# on some laptop keyboards. (e.g. CTRL-Caps lock is the same as CTRL -)
	# Please see bug #790
	$self->CmdKeyClear( Wx::wxSTC_KEY_SUBTRACT, Wx::wxSTC_SCMOD_CTRL );
	$self->CmdKeyClear( Wx::wxSTC_KEY_ADD,      Wx::wxSTC_SCMOD_CTRL );

	# Apply settings based on configuration
	# TO DO: Make this suck less (because it really does suck a lot)
	$self->apply_config($config);

	# Load the style data in the legacy evil way
	$data = data( $config->editor_style );

	# Generate basic event bindings
	Wx::Event::EVT_SET_FOCUS( $self, \&on_set_focus );
	Wx::Event::EVT_KILL_FOCUS( $self, \&on_kill_focus );
	Wx::Event::EVT_KEY_DOWN( $self, \&on_key_down );
	Wx::Event::EVT_KEY_UP( $self, \&on_key_up );
	Wx::Event::EVT_CHAR( $self, \&on_char );
	Wx::Event::EVT_MOTION( $self, \&on_mouse_moving );
	Wx::Event::EVT_MOUSEWHEEL( $self, \&on_mousewheel );
	Wx::Event::EVT_LEFT_DOWN( $self, \&on_left_down );
	Wx::Event::EVT_LEFT_UP( $self, \&on_left_up );
	Wx::Event::EVT_STC_DOUBLECLICK( $self, -1, \&on_left_double );
	Wx::Event::EVT_MIDDLE_UP( $self, \&on_middle_up );
	Wx::Event::EVT_RIGHT_DOWN( $self, \&on_right_down );

	# Capture change events that result in an actual change to the text
	# of the document, so we can refire content-dependent editor tools.
	$self->SetModEventMask(
		Wx::wxSTC_PERFORMED_USER | Wx::wxSTC_PERFORMED_UNDO | Wx::wxSTC_PERFORMED_REDO | Wx::wxSTC_MOD_INSERTTEXT
			| Wx::wxSTC_MOD_DELETETEXT );
	Wx::Event::EVT_STC_CHANGE( $self, $self, \&on_change );

	# Smart highlighting:
	# Selecting a word or small block of text causes all other occurrences to be highlighted
	# with a round box around each of them
	$self->{styles} = [];

	# Setup the editor indicators which we will use in smart, warning and error highlighting
	# Indicator #0: Green round box indicator for smart highlighting
	$self->IndicatorSetStyle( INDICATOR_SMART_HIGHLIGHT, Wx::wxSTC_INDIC_ROUNDBOX );

	# Indicator #1, Orange squiggle for warning highlighting
	$self->IndicatorSetForeground( INDICATOR_WARNING, ORANGE );
	$self->IndicatorSetStyle( INDICATOR_WARNING, Wx::wxSTC_INDIC_SQUIGGLE );

	# Indicator #2, Red squiggle for error highlighting
	$self->IndicatorSetForeground( INDICATOR_ERROR, RED );
	$self->IndicatorSetStyle( INDICATOR_ERROR, Wx::wxSTC_INDIC_SQUIGGLE );

	return $self;
}





######################################################################
# Event Handlers

# When the focus is received by the editor
sub on_set_focus {
	TRACE() if DEBUG;
	my $self     = shift;
	my $event    = shift;
	my $main     = $self->main;
	my $document = $self->{Document} or return;
	TRACE( "Focus received file:" . $document->get_title ) if DEBUG;

	# NOTE: The editor focus event fires a LOT, even for trivial things
	# like changing focus to another application and immediately back again,
	# or switching between tools in Padre.
	# Don't do any refreshing here, it is an excessive waste of resources.
	# Instead, put them in the events that ACTUALLY change application state.

	# TO DO
	# This is called even if the mouse is moved away from padre and back again
	# we should restrict some of the updates to cases when we switch from one file to
	# another
	if ( $self->needs_manual_colorize ) {
		TRACE("needs_manual_colorize") if DEBUG;
		my $lock  = $main->lock('UPDATE');
		my $lexer = $self->GetLexer;
		if ( $lexer == Wx::wxSTC_LEX_CONTAINER ) {
			$document->colorize;
		} else {
			$self->remove_color;
			$self->Colourise( 0, $self->GetLength );
		}
		$self->needs_manual_colorize(0);
	}

	# Keep processing
	$event->Skip(1);
}

# When the focus is leaving the editor
sub on_kill_focus {
	my $self  = shift;
	my $event = shift;

	# Squelch the change dwell timer
	$self->dwell_stop('on_change_dwell');

	# Keep processing
	$event->Skip(1);
}

# Called when a key is pressed
sub on_key_down {
	my $self  = shift;
	my $event = shift;
	$self->smart_highlight_hide;

	# Keep processing
	$event->Skip(1);
}

# Called when a key is released
sub on_key_up {
	my $self  = shift;
	my $event = shift;

	# The new behavior for a non-destructive CTRL-L
	if ( $event->GetKeyCode == ord('L') and $event->ControlDown ) {
		my $line = $self->GetLine( $self->GetCurrentLine );
		if ( $line !~ /^\s*$/ ) {

			# Only cut on non-blank lines
			$self->CmdKeyExecute(Wx::wxSTC_CMD_LINECUT);
		} else {

			# Otherwise delete the line
			$self->CmdKeyExecute(Wx::wxSTC_CMD_LINEDELETE);
		}
		$event->Skip(0); # done processing this nothing more to do
		return;
	}

	# Apply smart highlighting when the shift key is down
	if ( $event->ShiftDown and $self->config->editor_smart_highlight_enable ) {
		$self->smart_highlight_show;
	}

	# Doc specific processing
	my $doc = $self->{Document} or return;
	if ( $doc->can('event_key_up') ) {
		$doc->event_key_up( $self, $event );
	}

	# Keep processing
	$event->Skip(1);

}

# Called when a character is added or changed in the editor
sub on_char {
	my $self     = shift;
	my $event    = shift;
	my $document = $self->{Document} or return;
	if ( $document->can('event_on_char') ) {
		$document->event_on_char( $self, $event );
	}

	# Keep processing
	$event->Skip(1);
}

# Called on any change to text.
# NOTE: This gets called twice for every change, it may be a bug.
sub on_change {
	$_[0]->dwell_start( 'on_change_dwell', $_[0]->config->editor_dwell );
}

# Fires half a second after the user stops typing or otherwise stops changing
sub on_change_dwell {
	my $self   = shift;
	my $main   = $self->main;
	my $editor = $main->current->editor;

	# Only trigger tool refresh actions if we are the active document
	if ( $editor and $self->GetId == $editor->GetId ) {
		my $lock = $main->lock('UPDATE');
		$main->refresh_functions;
		$main->refresh_outline;
		$main->refresh_syntaxcheck;
	}

	return;
}

# Called while the mouse is moving
sub on_mouse_moving {
	my $self  = shift;
	my $event = shift;

	if ( $event->Moving ) {
		my $doc = $self->{Document} or return;
		if ( $doc->can('event_mouse_moving') ) {
			$doc->event_mouse_moving( $self, $event );
		}
	}

	# Keep processing
	$event->Skip(1);
}

# Convert the Ctrl-Scroll behaviour of changing the font size
# to the non-Ctrl behaviour of scrolling.
sub on_mousewheel {
	my $self  = shift;
	my $event = shift;

	# Ignore this handler if it's a normal wheel movement
	unless ( $event->ControlDown ) {
		$event->Skip(1);
		return;
	}

	if (Padre::Feature::FONTSIZE) {

		# The default handler zooms in the wrong direction
		$self->SetZoom( $self->GetZoom + int( $event->GetWheelRotation / $event->GetWheelDelta ) );
	} else {

		# Behave as if Ctrl wasn't down
		$self->ScrollLines( $event->GetLinesPerAction * int( $event->GetWheelRotation / $event->GetWheelDelta * -1 ) );
	}

	return;
}

sub on_left_down {
	my $self  = shift;
	my $event = shift;
	$self->smart_highlight_hide;

	# Keep processing
	$event->Skip(1);
}

sub on_left_up {
	my $self   = shift;
	my $event  = shift;
	my $config = $self->config;
	my $text   = $self->GetSelectedText;

	if ( Padre::Constant::WXGTK and defined $text and $text ne '' ) {

		# Only on X11 based platforms
		if ( $config->mid_button_paste ) {
			$self->put_text_to_clipboard( $text, 1 );
		} else {
			$self->put_text_to_clipboard($text);
		}
	}

	my $doc = $self->{Document};
	if ( $doc and $doc->can('event_on_left_up') ) {
		$doc->event_on_left_up( $self, $event );
	}

	# Keep processing
	$event->Skip(1);
}

sub on_left_double {
	my $self  = shift;
	my $event = shift;
	$self->smart_highlight_show;

	# Keep processing
	$event->Skip(1);
}

sub on_middle_up {
	my $self   = shift;
	my $event  = shift;
	my $config = $self->config;

	# TO DO: Sometimes there are unexpected effects when using the middle button.
	# It seems that another event is doing something but not within this module.
	# Please look at ticket #390 for details!
	if ( $config->mid_button_paste ) {
		Wx::wxTheClipboard->UsePrimarySelection(1);
	}

	if ( Padre::Constant::WIN32 or not $config->mid_button_paste ) {
		$self->Paste;
	}

	my $doc = $self->{Document};
	if ( $doc->can('event_on_middle_up') ) {
		$doc->event_on_middle_up( $self, $event );
	}

	if ( $config->mid_button_paste ) {
		Wx::wxTheClipboard->UsePrimarySelection(0);
		$event->Skip(1);
	} else {
		$event->Skip(0);
	}
}

sub on_right_down {
	my $self  = shift;
	my $event = shift;
	my $main  = $self->main;

	require Padre::Wx::Menu::RightClick;
	my $menu = Padre::Wx::Menu::RightClick->new( $main, $self, $event );

	if ( $event->isa('Wx::MouseEvent') ) {
		$self->PopupMenu( $menu->wx, $event->GetX, $event->GetY );
	} else { # Wx::CommandEvent
		$self->PopupMenu( $menu->wx, 50, 50 ); # TO DO better location
	}
}





######################################################################
# Setup and Preferences Methods

# Allow projects to override editor preferences
sub config {
	my $self    = shift;
	my $project = $self->current->project;
	return $project->config if $project;
	return $self->SUPER::config;
}

# Apply global configuration settings to the editor
sub apply_config {
	my $self   = shift;
	my $config = shift;

	# Apply various settings that largely map directly
	$self->SetCaretPeriod( $config->editor_cursor_blink );
	$self->SetCaretLineVisible( $config->editor_currentline );
	$self->SetViewEOL( $config->editor_eol );
	$self->SetViewWhiteSpace( $config->editor_whitespace );
	$self->show_line_numbers( $config->editor_linenumbers );
	$self->SetIndentationGuides( $config->editor_indentationguides );

	# Enable or disable word wrapping
	if ( $config->editor_wordwrap ) {
		$self->SetWrapMode(Wx::wxSTC_WRAP_WORD);
	} else {
		$self->SetWrapMode(Wx::wxSTC_WRAP_NONE);
	}

	# Enable or disable the right hand margin guideline
	if ( $config->editor_right_margin_enable ) {
		$self->SetEdgeColumn( $config->editor_right_margin_column );
		$self->SetEdgeMode(Wx::wxSTC_EDGE_LINE);
	} else {
		$self->SetEdgeMode(Wx::wxSTC_EDGE_NONE);
	}

	# Set the font
	my $font = Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL );
	if ( defined $config->editor_font and length $config->editor_font > 0 ) {
		$font->SetNativeFontInfoUserDesc( $config->editor_font );
	}
	$self->SetFont($font);
	$self->StyleSetFont( Wx::wxSTC_STYLE_DEFAULT, $font );

	# Enable or disable folding (if folding is turned on)
	if (Padre::Feature::FOLDING) {
		$self->show_folding( $config->editor_folding );
	}

	return;
}

# Applys the document content to the editor before plugins get notified
sub configure_editor {
	my $self     = shift;
	my $document = shift or return;
	my $eol      = $WXEOL{ $document->newline_type };
	$self->SetEOLMode($eol) if defined $eol;

	if ( defined $document->{original_content} ) {
		$self->SetText( $document->{original_content} );
	}

	$self->EmptyUndoBuffer;

	return;
}

sub set_preferences {
	my $self = shift;
	my $config = shift || $self->config;

	# (Re)apply general configuration settings
	$self->apply_config($config);

	# Apply type-specific settings
	$self->padre_setup($config);

	if ( $self->{Document} ) {
		$self->{Document}->set_indentation_style;
	}

	return;
}

# Most of this should be read from some external files
# but for now we use this if statement
sub padre_setup {
	my $self     = shift;
	my $config   = shift || $self->config;
	my $document = $self->{Document};
	my $filename = $document ? $document->filename : '';
	my $mimetype = $document ? $document->mimetype : 'text/plain';

	# Configure lexing for the editor based on the document type
	if ($document) {
		$self->SetLexer( $document->lexer );
		$self->SetWordChars( $document->stc_word_chars );

		# Set all the lexer keywords lists that the document provides
		my @lexer_keywords = @{ $document->lexer_keywords };
		for my $i ( 0 .. $#lexer_keywords ) {
			$self->SetKeyWords( $i, join( ' ', @{ $lexer_keywords[$i] } ) );
		}
	} else {
		$self->SetWordChars('');
	}

	# Apply the blanket plain styling to everything first
	$self->padre_setup_plain($config);

	# Setup the style for the specific mimetype
	if ( $MIME_STYLE{$mimetype} ) {
		$self->padre_setup_style( $MIME_STYLE{$mimetype}, $config );
		return;
	}

	# Setup some default colouring.
	# For the time being it is the same as for Perl.
	unless ( $mimetype ne 'text/plain' ) {
		$self->padre_setup_style( 'padre', $config );
		return;
	}

	# For plain text try to guess based on the filename
	if ( $filename and $filename =~ /\.([^.]+)$/ ) {
		my $ext = lc $1;

		# Resetup if file extension is .conf
		if ( $ext eq 'conf' ) {
			$self->padre_setup_style( 'conf', $config );
			return;
		}
	}

	return;
}

sub padre_setup_plain {
	my $self   = shift;
	my $config = shift || $self->config;
	my $plain  = $data->{plain};

	# Flush the style colouring and apply from scratch
	$self->StyleClearAll;

	if ( defined $plain->{current_line_foreground} ) {
		$self->SetCaretForeground( Padre::Wx::color( $plain->{current_line_foreground} ) );
	}
	if ( defined $plain->{currentline} ) {
		if ( defined $config->editor_currentline_color ) {
			if ( $plain->{currentline} ne $config->editor_currentline_color ) {
				$plain->{currentline} = $config->editor_currentline_color;
			}
		}
		$self->SetCaretLineBackground( Padre::Wx::color( $plain->{currentline} ) );
	} elsif ( defined $config->editor_currentline_color ) {
		$self->SetCaretLineBackground( Padre::Wx::color( $config->editor_currentline_color ) );
	}

	my $foregrounds = $plain->{foregrounds};
	foreach my $k ( keys %$foregrounds ) {
		$self->StyleSetForeground( $k => Padre::Wx::color( $plain->{foregrounds}->{$k} ) );
	}

	$self->setup_style_from_config( 'plain', $config );

	return;
}

sub padre_setup_style {
	my $self   = shift;
	my $name   = shift;
	my $config = shift || $self->config;

	foreach my $i ( 0 .. Wx::wxSTC_STYLE_DEFAULT ) {
		$self->StyleSetBackground( $i => Padre::Wx::color( $data->{$name}->{background} ) );
	}

	$self->setup_style_from_config( $name, $config );

	# if mimetype is known, then it might be Perl with in-line POD
	if ( Padre::Feature::FOLDING and $config->editor_folding ) {
		if ( $config->editor_fold_pod ) {
			$self->fold_pod;
		}
	}

	return;
}

sub setup_style_from_config {
	my $self   = shift;
	my $name   = shift;
	my $config = shift || $self->config; # Unused but leave it here for now
	my $style  = $data->{$name};
	my $colors = $style->{colors};

	# The selection background (if applicable)
	# (The Scintilla official selection background colour is cc0000)
	if ( $style->{selection_background} ) {
		$self->SetSelBackground(
			1 => Padre::Wx::color( $style->{selection_background} ),
		);
	}
	if ( $style->{selection_foreground} ) {
		$self->SetSelForeground(
			1 => Padre::Wx::color( $style->{selection_foreground} ),
		);
	}

	# Set the styles
	foreach my $k ( keys %$colors ) {
		my $v;

		# allow for plain numbers
		if ( $k =~ /^\d+$/ ) {
			$v = $k;
		}

		# but normally, we have Wx:: or PADRE_ constants
		else {
			my $f = 'Wx::' . $k;
			if ( $k =~ /^PADRE_/ ) {
				$f = 'Padre::Constant::' . $k;
			}
			no strict "refs";
			$v = eval { $f->() };
			if ($@) {
				warn "invalid key '$k'\n";
				next;
			}
		}

		my $color = $data->{$name}->{colors}->{$k};
		if ( exists $color->{foreground} ) {
			$self->StyleSetForeground( $v => Padre::Wx::color( $color->{foreground} ) );
		}
		if ( exists $color->{background} ) {
			$self->StyleSetBackground( $v => Padre::Wx::color( $color->{background} ) );
		}
		if ( exists $color->{bold} ) {
			$self->StyleSetBold( $v, $color->{bold} );
		}
		if ( exists $color->{italics} ) {
			$self->StyleSetItalic( $v, $color->{italic} );
		}
		if ( exists $color->{eolfilled} ) {
			$self->StyleSetEOLFilled( $v, $color->{eolfilled} );
		}
		if ( exists $color->{underlined} ) {
			$self->StyleSetUnderline( $v, $color->{underline} );
		}
	}
}





######################################################################
# General Methods

# convenience methods
# return the character at a given position as a perl string
sub get_character_at {
	return chr $_[0]->GetCharAt( $_[1] );
}

# private is undefined if we don't know and need to search for it
# private is 0 if this is a standard style
# private is 1 if this is a private style
sub data {
	my $name    = shift;
	my $private = shift;

	return $data if not defined $name;
	return $data if defined $data and $name eq $data_name;

	my $private_file = File::Spec->catfile( Padre::Constant::CONFIG_DIR, 'styles', "$name.yml" );
	my $standard_file = Padre::Util::sharefile( 'styles', "$name.yml" );

	if ( not defined $private ) {
		if ( -e $private_file ) {
			$private = 1;
		} elsif ( -e $standard_file ) {
			$private = 0;
		} else {
			warn "style $name could not be found in either places: '$standard_file' and '$private_file'\n";
			return $data;
		}
	}

	my $file =
		  $private
		? $private_file
		: $standard_file;
	my $tdata;
	eval { $tdata = YAML::Tiny::LoadFile($file); };
	if ($@) {
		warn $@;
	} else {
		$data_name    = $name;
		$data_private = $private;
		$data         = $tdata;
	}
	return $data;
}

# Error Message
sub error {
	my $self = shift;
	my $text = shift;
	Wx::MessageBox(
		$text,
		Wx::gettext("Error"),
		Wx::wxOK,
		$self->main
	);
}

sub remove_color {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# TO DO this is strange, do we really need to do it with all?
	foreach my $i ( 0 .. 31 ) {
		$self->StartStyling( 0, $i );
		$self->SetStyling( $self->GetLength, 0 );
	}

	return;
}

=head2 get_brace_info

Look at a given position in the editor if there is a brace (according to the
setting editor_braces) before or after, and return the information about the context
It always look first at the character after the position.

	Params:
		pos - the cursor position in the editor [defaults to cursor position) : int

	Return:
		undef if no brace, otherwise [brace, actual_pos, is_after, is_opening]
		where:
			brace - the brace char at actual_pos
			actual_pos - the actual position where the brace has been found
			is_after - true iff the brace is after the cursor : boolean
			is_opening - true iff only the brace is an opening one

	Examples:

		|{} => should find the { : [0,{,1,1]
		{|} => should find the } : [1,},1,0]
		{| } => should find the { : [0,{,0,1]

=cut

sub get_brace_info {
	my ( $self, $pos ) = @_;
	$pos = $self->GetCurrentPos unless defined $pos;

	# try the after position first (default one for BraceMatch)
	my $is_after = 1;
	my $brace    = $self->get_character_at($pos);
	my $is_brace = $self->get_brace_type($brace);
	if ( !$is_brace && $pos > 0 ) { # try the before position
		$brace    = $self->get_character_at( --$pos );
		$is_brace = $self->get_brace_type($brace) or return undef;
		$is_after = 0;
	}
	my $is_opening = $is_brace % 2; # odd values are opening
	return [ $pos, $brace, $is_after, $is_opening ];
}

=head2 get_brace_type

Tell if a character is a brace, and if it is an opening or a closing one

	Params:
		char - a character : string

	Return:
		int : 0 if this is not a brace, an odd value if it is an opening brace and an even
		one for a closing brace

=cut

my %_cached_braces;

sub get_brace_type {
	my $self = shift;
	my $char = shift;
	unless (%_cached_braces) {
		my $i = 1; # start from one so that all values are true
		$_cached_braces{$_} = $i++ foreach ( split //, '{}[]()' );
	}
	my $v = $_cached_braces{$char} or return 0;
	return $v;
}

my $previous_expr_hiliting_style;

sub highlight_braces {
	my $self                    = shift;
	my $expression_highlighting = $self->config->editor_brace_expression_highlighting;

	# remove current highlighting if any
	$self->BraceHighlight( Wx::wxSTC_INVALID_POSITION, Wx::wxSTC_INVALID_POSITION );
	if ($previous_expr_hiliting_style) {
		$self->apply_style($previous_expr_hiliting_style);
		$previous_expr_hiliting_style = undef;
	}

	my $pos1          = $self->GetCurrentPos;
	my $info1         = $self->get_brace_info($pos1) or return;
	my ($actual_pos1) = @$info1;

	my $actual_pos2 = $self->BraceMatch($actual_pos1);

	return if $actual_pos2 == Wx::wxSTC_INVALID_POSITION; #Wx::wxSTC_INVALID_POSITION  #????

	$self->BraceHighlight( $actual_pos1, $actual_pos2 );

	if ($expression_highlighting) {
		my $pos2 = $self->find_matching_brace($pos1) or return;
		my %style = (
			start => $pos1 < $pos2 ? $pos1 : $pos2,
			len => abs( $pos1 - $pos2 ), style => Wx::wxSTC_STYLE_DEFAULT
		);
		$previous_expr_hiliting_style = $self->apply_style( \%style );
	}


	return;
}

# some uncorrect behaviour (| is the cursor)
# {} : never highlighted
# { } : always correct
#
#

sub apply_style {
	my $self           = shift;
	my $style_info     = shift;
	my %previous_style = %$style_info;
	$previous_style{style} = $self->GetStyleAt( $style_info->{start} );

	$self->StartStyling( $style_info->{start}, 0xFF );
	$self->SetStyling( $style_info->{len}, $style_info->{style} );

	return \%previous_style;
}

=head2 find_matching_brace

Find the position of to the matching brace if any. If the cursor is inside the braces the destination
will be inside too, same it is outside.

	Params:
		pos - the cursor position in the editor [defaults to cursor position) : int

	Return:
		matching_pos - the matching position, or undef if none

=cut

sub find_matching_brace {
	my ( $self, $pos ) = @_;
	$pos = $self->GetCurrentPos unless defined $pos;
	my $info1 = $self->get_brace_info($pos) or return;
	my ( $actual_pos1, $brace, $is_after, $is_opening ) = @$info1;

	my $actual_pos2 = $self->BraceMatch($actual_pos1);
	return if $actual_pos2 == Wx::wxSTC_INVALID_POSITION;
	$actual_pos2++ if $is_after; # ensure is stays inside if origin is inside, same four outside
	return $actual_pos2;
}


=head2 goto_matching_brace

Move the cursor to the matching brace if any. If the cursor is inside the braces the destination
will be inside too, same it is outside.

	Params:
		pos - the cursor position in the editor [defaults to cursor position) : int

=cut

sub goto_matching_brace {
	my ( $self, $pos ) = @_;
	my $pos2 = $self->find_matching_brace($pos) or return;
	$self->GotoPos($pos2);
}

=head2 select_to_matching_brace

Select to the matching opening or closing brace. If the cursor is inside the braces the destination
will be inside too, same it is outside.

	Params:
		pos - the cursor position in the editor [defaults to cursor position) : int

=cut

sub select_to_matching_brace {
	my ( $self, $pos ) = @_;
	$pos = $self->GetCurrentPos unless defined $pos;
	my $pos2 = $self->find_matching_brace($pos) or return;
	my $start = ( $pos < $pos2 ) ? $self->GetSelectionStart : $self->GetSelectionEnd;
	$self->SetSelection( $start, $pos2 );

}

# currently if there are 9 lines we set the margin to 1 width and then
# if another line is added it is not seen well.
# actually I added some improvement allowing a 50% growth in the file
# and requireing a min of 2 width
sub show_line_numbers {
	my $self = shift;
	my $on   = shift;

	if ($on) {
		my $n = 1 + List::Util::max( 2, length( $self->GetLineCount * 2 ) );
		my $width = $n * $self->TextWidth( Wx::wxSTC_STYLE_LINENUMBER, "m" );
		$self->SetMarginWidth( 0, $width );
		$self->SetMarginType( 0, Wx::wxSTC_MARGIN_NUMBER );
	} else {
		$self->SetMarginWidth( 0, 0 );
		$self->SetMarginType( 0, Wx::wxSTC_MARGIN_NUMBER );
	}

	return;
}

sub show_calltip {
	my $self   = shift;
	my $config = $self->config;
	return unless $config->editor_calltips;

	my $pos    = $self->GetCurrentPos;
	my $line   = $self->LineFromPosition($pos);
	my $first  = $self->PositionFromLine($line);
	my $prefix = $self->GetTextRange( $first, $pos ); # line from beginning to current position
	if ( $self->CallTipActive ) {
		$self->CallTipCancel;
	}

	my $doc      = $self->current->document or return;
	my $keywords = $doc->keywords;
	my $regex    = join '|', sort { length $a <=> length $b } keys %$keywords;

	my $tip;
	if ( $prefix =~ /(?:^|[^\w\$\@\%\&])($regex)[ (]?$/ ) {
		my $z = $keywords->{$1};
		return if not $z or not ref($z) or ref($z) ne 'HASH';
		$tip = "$z->{cmd}\n$z->{exp}";
	}
	if ($tip) {
		$self->CallTipShow( $self->CallTipPosAtStart + 1, $tip );
	}
	return;
}

# For auto-indentation (i.e. one more level), we do the following:
# 1) get the white spaces of the previous line and add them here as well
# 2) after a brace indent one level more than previous line
# 3) while doing all this, respect the current (sadly global) indentation settings
# For auto-de-indentation (i.e. closing brace), we remove one level of indentation
# instead.
# FIX ME/TO DO: needs some refactoring
sub autoindent {
	my ( $self, $mode ) = @_;

	my $config = $self->config;
	return unless $config->editor_autoindent;
	return if $config->editor_autoindent eq 'no';

	if ( $mode eq 'deindent' ) {
		$self->_auto_deindent($config);
	} else {

		# default to "indent"
		$self->_auto_indent($config);
	}

	return;
}

sub _auto_indent {
	my ( $self, $config ) = @_;

	my $pos       = $self->GetCurrentPos;
	my $prev_line = $self->LineFromPosition($pos) - 1;
	return if $prev_line < 0;

	my $indent_style = $self->{Document}->get_indentation_style;

	my $content = $self->GetLine($prev_line);
	my $eol     = $self->{Document}->newline;
	$content =~ s/$eol$//;
	my $indent = ( $content =~ /^(\s+)/ ? $1 : '' );

	if ( $config->editor_autoindent eq 'deep' and $content =~ /\{\s*$/ ) {
		my $indent_width = $indent_style->{indentwidth};
		my $tab_width    = $indent_style->{tabwidth};
		if ( $indent_style->{use_tabs} and $indent_width != $tab_width ) {

			# do tab compression if necessary
			# - First, convert all to spaces (aka columns)
			# - Then, add an indentation level
			# - Then, convert to tabs as necessary
			my $tab_equivalent = " " x $tab_width;
			$indent =~ s/\t/$tab_equivalent/g;
			$indent .= $tab_equivalent;
			$indent =~ s/$tab_equivalent/\t/g;
		} elsif ( $indent_style->{use_tabs} ) {

			# use tabs only
			$indent .= "\t";
		} else {
			$indent .= " " x $indent_width;
		}
	}
	if ( $indent ne '' ) {
		$self->InsertText( $pos, $indent );
		$self->GotoPos( $pos + length($indent) );
	}

	return;
}

sub _auto_deindent {
	my ( $self, $config ) = @_;

	my $pos  = $self->GetCurrentPos;
	my $line = $self->LineFromPosition($pos);

	my $indent_style = $self->{Document}->get_indentation_style;

	my $content = $self->GetLine($line);
	my $indent = ( $content =~ /^(\s+)/ ? $1 : '' );

	# This is for } on a new line:
	if ( $config->editor_autoindent eq 'deep' and $content =~ /^\s*\}\s*$/ ) {
		my $prev_line    = $line - 1;
		my $prev_content = ( $prev_line < 0 ? '' : $self->GetLine($prev_line) );
		my $prev_indent  = ( $prev_content =~ /^(\s+)/ ? $1 : '' );

		# de-indent only in these cases:
		# - same indentation level as prev. line and not a brace on prev line
		# - higher indentation than pr. l. and a brace on pr. line
		if ( $prev_indent eq $indent && $prev_content !~ /^\s*{/
			or length($prev_indent) < length($indent) && $prev_content =~ /\{\s*$/ )
		{
			my $indent_width = $indent_style->{indentwidth};
			my $tab_width    = $indent_style->{tabwidth};
			if ( $indent_style->{use_tabs} and $indent_width != $tab_width ) {

				# do tab compression if necessary
				# - First, convert all to spaces (aka columns)
				# - Then, add an indentation level
				# - Then, convert to tabs as necessary
				my $tab_equivalent = " " x $tab_width;
				$indent =~ s/\t/$tab_equivalent/g;
				$indent =~ s/$tab_equivalent$//;
				$indent =~ s/$tab_equivalent/\t/g;
			} elsif ( $indent_style->{use_tabs} ) {

				# use tabs only
				$indent =~ s/\t$//;
			} else {
				my $indentation_level = " " x $indent_width;
				$indent =~ s/$indentation_level$//;
			}
		}

		# replace indentation of the current line
		$self->GotoPos( $pos - 1 );
		$self->DelLineLeft;
		$pos = $self->GetCurrentPos;
		$self->InsertText( $pos, $indent );
		$self->GotoPos( $self->GetLineEndPosition($line) );
	}

	# this is if the line matches "blahblahSomeText}".
	elsif ( $config->editor_autoindent eq 'deep' and $content =~ /\}\s*$/ ) {

		# TO DO: What should happen in this case?
	}

	return;
}

sub text_selection_mark_start {
	my $self = shift;
	$self->{selection_mark_start} = $self->GetCurrentPos;

	# Change selection if start and end are defined
	if ( defined $self->{selection_mark_end} ) {
		$self->SetSelection(
			$self->{selection_mark_start},
			$self->{selection_mark_end}
		);
	}
}

sub text_selection_mark_end {
	my $self = shift;
	$self->{selection_mark_end} = $self->GetCurrentPos;

	# Change selection if start and end are defined
	if ( defined $self->{selection_mark_start} ) {
		$self->SetSelection(
			$self->{selection_mark_start},
			$self->{selection_mark_end}
		);
	}
}

sub text_selection_clear {
	my $editor = shift;
	$editor->{selection_mark_start} = undef;
	$editor->{selection_mark_end}   = undef;
}

#
# my ($begin, $end) = $self->current_paragraph;
#
# return $begin and $end position of current paragraph.
#
sub current_paragraph {
	my ($editor) = @_;

	my $curpos = $editor->GetCurrentPos;
	my $lineno = $editor->LineFromPosition($curpos);

	# check if we're in between paragraphs
	return ( $curpos, $curpos ) if $editor->GetLine($lineno) =~ /^\s*$/;

	# find the start of paragraph by searching backwards till we find a
	# line with only whitespace in it.
	my $para1 = $lineno;
	while ( $para1 > 0 ) {
		my $line = $editor->GetLine($para1);
		last if $line =~ /^\s*$/;
		$para1--;
	}

	# now, find the end of paragraph by searching forwards until we find
	# only white space
	my $lastline = $editor->GetLineCount;
	my $para2    = $lineno;
	while ( $para2 < $lastline ) {
		$para2++;
		my $line = $editor->GetLine($para2);
		last if $line =~ /^\s*$/;
	}

	# return the position
	my $begin = $editor->PositionFromLine( $para1 + 1 );
	my $end   = $editor->PositionFromLine($para2);
	return ( $begin, $end );
}

# TO DO: include the changing of file type in the undo/redo actions
# or better yet somehow fetch it from the document when it is needed.
sub convert_eols {
	my $self    = shift;
	my $newline = shift;
	my $mode    = $WXEOL{$newline};

	# Apply the change to the underlying document
	my $document = $self->{Document} or return;
	$document->set_newline_type($newline);

	# Convert and Set the EOL mode in the editor
	$self->ConvertEOLs($mode);
	$self->SetEOLMode($mode);

	return 1;
}

sub Paste {
	my $self = shift;

	# Workaround for Copy/Paste bug ticket #390
	my $text = $self->get_text_from_clipboard;

	if ($text) {

		# Conversion of pasted text is really needed since it usually comes
		# with the platform's line endings
		#
		# Please see ticket:589, "Pasting in a UNIX document in win32
		# corrupts it to MIXEd"
		$self->ReplaceSelection( $self->_convert_paste_eols($text) );
	}

	return 1;
}

#
# This method converts line ending based on current document EOL mode
# and the newline type for the current text
#
sub _convert_paste_eols {
	my ( $self, $paste ) = @_;

	my $newline_type = Padre::Util::newline_type($paste);
	my $eol_mode     = $self->GetEOLMode;

	# Handle the 'None' one-liner case
	if ( $newline_type eq 'None' ) {
		$newline_type = $self->config->default_line_ending;
	}

	#line endings
	my $CR   = "\015";
	my $LF   = "\012";
	my $CRLF = "$CR$LF";
	my ( $from, $to );

	# From what to convert from?
	if ( $newline_type eq 'WIN' ) {
		$from = $CRLF;
	} elsif ( $newline_type eq 'UNIX' ) {
		$from = $LF;
	} elsif ( $newline_type eq 'MAC' ) {
		$from = $CR;
	}

	# To what to convert to?
	if ( $eol_mode eq Wx::wxSTC_EOL_CRLF ) {
		$to = $CRLF;
	} elsif ( $eol_mode eq Wx::wxSTC_EOL_LF ) {
		$to = $LF;
	} else {

		#must be Wx::wxSTC_EOL_CR
		$to = $CR;
	}

	# Convert only when it is needed
	if ( $from ne $to ) {
		$paste =~ s/$from/$to/g;
	}

	return $paste;
}

sub put_text_to_clipboard {
	my ( $self, $text, $clipboard ) = @_;
	@_ = (); # Feeble attempt to kill Scalars Leaked

	return if $text eq '';

	my $config = $self->config;

	$clipboard ||= 0;

	# Backup last clipboard value:
	$self->{Clipboard_Old} = $self->get_text_from_clipboard;

	#         if $self->{Clipboard_Old} ne $self->get_text_from_clipboard;

	Wx::wxTheClipboard->Open;
	Wx::wxTheClipboard->UsePrimarySelection($clipboard)
		if $config->mid_button_paste;
	Wx::wxTheClipboard->SetData( Wx::TextDataObject->new($text) );
	Wx::wxTheClipboard->Close;

	return;
}

sub get_text_from_clipboard {
	my $self = shift;
	my $text = '';
	Wx::wxTheClipboard->Open;
	if ( Wx::wxTheClipboard->IsSupported(Wx::wxDF_TEXT) ) {
		my $data = Wx::TextDataObject->new;
		if ( Wx::wxTheClipboard->GetData($data) ) {
			$text = $data->GetText if defined $data;
		}
	}
	if ( $text eq $self->GetSelectedText ) {
		$text = $self->{Clipboard_Old};
	}

	Wx::wxTheClipboard->Close;
	return $text;
}

# Comment or uncomment text depending on the first selected line.
# This is the most coherent way to handle mixed blocks (commented and
# uncommented lines).
sub comment_toggle_lines {
	my ( $self, $begin, $end, $str ) = @_;

	my $comment = ref $str eq 'ARRAY' ? $str->[0] : $str;

	if ( $self->GetLine($begin) =~ /^\s*\Q$comment\E/ ) {
		uncomment_lines(@_);
	} else {
		comment_lines(@_);
	}
}

# $editor->comment_lines($begin, $end, $str);
# $str is either # for perl or // for Javascript, etc.
# $str might be ['<--', '-->] for html
#
# Change: for Single lines comments, it will (un)comment with indent:
# <indent>$comment_characters<space>XXXXXXX
# If someone has idee for commenting Haskell Guards in Single lines,
# (well, ('-- |') is a symbol for haddock.) please fix it.
#
sub comment_lines {
	my ( $self, $begin, $end, $str ) = @_;

	$self->BeginUndoAction;
	if ( ref $str eq 'ARRAY' ) {
		my $pos = $self->PositionFromLine($begin);
		$self->InsertText( $pos, $str->[0] );
		$pos = $self->GetLineEndPosition($end);
		$self->InsertText( $pos, $str->[1] );
	} else {
		foreach my $line ( $begin .. $end ) {
			my $text = $self->GetLine($line);
			if ( $text =~ /^(\s*)/ ) {
				my $pos = $self->PositionFromLine($line);
				$pos += length($1);
				$self->InsertText( $pos, $str . ' ' );
			}
		}
	}
	$self->EndUndoAction;

	return;
}

#
# $editor->uncomment_lines($begin, $end, $str);
#
# uncomment lines $begin..$end
# Change: see comments for `comment_lines()`
#
sub uncomment_lines {
	my ( $self, $begin, $end, $str ) = @_;

	$self->BeginUndoAction;
	if ( ref $str eq 'ARRAY' ) {
		my $first = $self->PositionFromLine($begin);
		my $last  = $first + length( $str->[0] );
		my $text  = $self->GetTextRange( $first, $last );
		if ( $text eq $str->[0] ) {
			$self->SetSelection( $first, $last );
			$self->ReplaceSelection('');
		}
		$last  = $self->GetLineEndPosition($end);
		$first = $last - length( $str->[1] );
		$text  = $self->GetTextRange( $first, $last );
		if ( $text eq $str->[1] ) {
			$self->SetSelection( $first, $last );
			$self->ReplaceSelection('');
		}
	} else {
		foreach my $line ( $begin .. $end ) {
			my $text = $self->GetLine($line);

			# the first line starting with '#!' can't be uncommented!
			next if ( $line == 0 && $text =~ /^#!/ );

			if ( $text =~ /^(\s*)(\Q$str\E\s*)/ ) {
				my $start = $self->PositionFromLine($line) + length($1);

				$self->SetSelection( $start, $start + length($2) );
				$self->ReplaceSelection('');
			}
		}
	}
	$self->EndUndoAction;

	return;
}

sub find_function {
	my $self     = shift;
	my $name     = shift;
	my $document = $self->{Document} or return;
	my $regex    = $document->get_function_regex($name) or return;

	# Run the search
	my ( $start, $end ) = Padre::Util::get_matches(
		$self->GetText,
		$regex,
		$self->GetSelection, # Provides two params
	);

	return $start;
}

sub has_function {
	defined shift->find_function(@_);
}

sub goto_function {
	my $self  = shift;
	my $start = $self->find_function(shift);
	return unless defined $start;
	$self->goto_pos_centerize($start);
}

sub goto_line_centerize {
	my $self = shift;
	my $line = shift;
	$self->goto_pos_centerize( $self->GetLineIndentPosition($line) );
}

# CREDIT: Borrowed from Kephra
sub goto_pos_centerize {
	my $self = shift;
	my $pos  = shift;
	my $max  = $self->GetLength;
	$pos = 0 unless $pos or $pos < 0;
	$pos = $max if $pos > $max;

	$self->SetCurrentPos($pos);
	$self->SearchAnchor;

	my $line = $self->GetCurrentLine;
	$self->ScrollToLine( $line - $self->LinesOnScreen / 2 );
	$self->EnsureVisible($line);
	$self->EnsureCaretVisible;
	$self->SetSelection( $pos, $pos );
	$self->SetFocus;

	return 1;
}

sub insert_text {
	my $self = shift;
	my $text = shift;
	my $size = Wx::TextDataObject->new($text)->GetTextLength;
	my $pos  = $self->GetCurrentPos;
	$self->ReplaceSelection('');
	$self->InsertText( $pos, $text );
	$self->GotoPos( $pos + $size + 1 );
	return 1;
}

sub insert_from_file {
	my $self = shift;
	my $file = shift;
	open( my $fh, '<', $file ) or return;
	binmode($fh);
	local $/ = undef;
	my $text = <$fh>;
	close $fh;
	$self->insert_text($text);
}

sub vertically_align {
	my $editor = shift;

	# Get the selected lines
	my $begin = $editor->LineFromPosition( $editor->GetSelectionStart );
	my $end   = $editor->LineFromPosition( $editor->GetSelectionEnd );
	if ( $begin == $end ) {
		$editor->error( Wx::gettext("You must select a range of lines") );
		return;
	}
	my @line = ( $begin .. $end );
	my @text = ();
	foreach (@line) {
		my $x = $editor->PositionFromLine($_);
		my $y = $editor->GetLineEndPosition($_);
		push @text, $editor->GetTextRange( $x, $y );
	}

	# Get the align character from the selection start
	# (which must be a non-whitespace non-word character)
	my $start = $editor->GetSelectionStart;
	my $c = $editor->GetTextRange( $start, $start + 1 );
	unless ( defined $c and $c =~ /^[^\s\w]$/ ) {
		$editor->error( Wx::gettext("First character of selection must be a non-word character to align") );
	}

	# Locate the position of the align character,
	# and the position of the earliest whitespace before it.
	my $qc       = quotemeta $c;
	my @position = ();
	foreach (@text) {
		if (/^(.+?)(\s*)$qc/) {
			push @position, [ length("$1"), length("$2") ];
		} else {

			# This line is not a member of the align set
			push @position, undef;
		}
	}

	# Find the latest position of the starting whitespace.
	my $longest = List::Util::max map { $_->[0] } grep {$_} @position;

	# Now lets line them up
	$editor->BeginUndoAction;
	foreach ( 0 .. $#line ) {
		next unless $position[$_];
		my $spaces = $longest - $position[$_]->[0] - $position[$_]->[1] + 1;
		if ( $_ == 0 ) {
			$start = $start + $spaces;
		}
		my $insert = $editor->PositionFromLine( $line[$_] ) + $position[$_]->[0];
		if ( $spaces > 0 ) {
			$editor->InsertText( $insert, ' ' x $spaces );
		} elsif ( $spaces < 0 ) {
			$editor->SetSelection( $insert, $insert - $spaces );
			$editor->ReplaceSelection('');
		}
	}
	$editor->EndUndoAction;

	# Move the selection to the new position
	$editor->SetSelection( $start, $start );

	return;
}

sub needs_manual_colorize {
	if ( defined $_[1] ) {
		$_[0]->{needs_manual_colorize} = $_[1];
	}
	return $_[0]->{needs_manual_colorize};
}





######################################################################
# Smart Highlighting

sub smart_highlight_show {
	my $self             = shift;
	my $selection        = $self->GetSelectedText;
	my $selection_length = length $selection;
	return if $selection_length == 0;

	my $selection_re = quotemeta $selection;
	my $line_count   = $self->GetLineCount;
	my $line_num     = $self->GetCurrentLine;

	# Limits search to C+N..C-N from current line respecting limits ofcourse
	# to optimize CPU usage
	my $NUM_LINES = 400;
	my $from      = ( $line_num - $NUM_LINES <= 0 ) ? 0 : $line_num - $NUM_LINES;
	my $to        = ( $line_count <= $line_num + $NUM_LINES ) ? $line_count : $line_num + $NUM_LINES;

	# Clear previous smart highlights
	$self->smart_highlight_hide;

	# find matching occurrences
	foreach my $i ( $from .. $to ) {
		my $line_start = $self->PositionFromLine($i);
		my $line       = $self->GetLine($i);
		while ( $line =~ /$selection_re/g ) {
			my $start = $line_start + pos($line) - $selection_length;

			push @{ $self->{styles} },
				{
				start => $start,
				len   => $selection_length,
				style => $self->GetStyleAt($start)
				};
		}
	}

	# smart highlight if there are more than one occurrence...
	if ( scalar @{ $self->{styles} } > 1 ) {
		foreach my $style ( @{ $self->{styles} } ) {
			$self->StartStyling( $style->{start}, 0xFF );
			$self->SetStyling( $style->{len}, Wx::wxSTC_STYLE_DEFAULT );
		}
	}

}

sub smart_highlight_hide {
	my $self = shift;

	my @styles = @{ $self->{styles} };
	if ( scalar @styles ) {
		foreach my $style (@styles) {
			$self->StartStyling( $style->{start}, 0xFF );
			$self->SetStyling( $style->{len}, $style->{style} );
		}
		$#{ $self->{styles} } = -1;
	}
}





######################################################################
# Code Folding

no warnings 'once';

BEGIN {
	*show_folding = sub {
		my $self = shift;
		my $on   = shift;

		if ($on) {

			# Setup a margin to hold fold markers
			$self->SetMarginType( 2, Wx::wxSTC_MARGIN_SYMBOL ); # margin number 2 for symbols
			$self->SetMarginMask( 2, Wx::wxSTC_MASK_FOLDERS );  # set up mask for folding symbols
			$self->SetMarginSensitive( 2, 1 );                  # this one needs to be mouse-aware
			$self->SetMarginWidth( 2, 16 );                     # set margin 2 16 px wide

			# Define folding markers
			my $w = Wx::Colour->new("white");
			my $b = Wx::Colour->new("black");
			$self->MarkerDefine( Wx::wxSTC_MARKNUM_FOLDEREND,     Wx::wxSTC_MARK_BOXPLUSCONNECTED,  $w, $b );
			$self->MarkerDefine( Wx::wxSTC_MARKNUM_FOLDEROPENMID, Wx::wxSTC_MARK_BOXMINUSCONNECTED, $w, $b );
			$self->MarkerDefine( Wx::wxSTC_MARKNUM_FOLDERMIDTAIL, Wx::wxSTC_MARK_TCORNER,           $w, $b );
			$self->MarkerDefine( Wx::wxSTC_MARKNUM_FOLDERTAIL,    Wx::wxSTC_MARK_LCORNER,           $w, $b );
			$self->MarkerDefine( Wx::wxSTC_MARKNUM_FOLDERSUB,     Wx::wxSTC_MARK_VLINE,             $w, $b );
			$self->MarkerDefine( Wx::wxSTC_MARKNUM_FOLDER,        Wx::wxSTC_MARK_BOXPLUS,           $w, $b );
			$self->MarkerDefine( Wx::wxSTC_MARKNUM_FOLDEROPEN,    Wx::wxSTC_MARK_BOXMINUS,          $w, $b );

			# This would be nice but the color used for drawing the lines is
			# Wx::wxSTC_STYLE_DEFAULT, i.e. usually black and therefore quite
			# obtrusive...
			# $self->SetFoldFlags( Wx::wxSTC_FOLDFLAG_LINEBEFORE_CONTRACTED | Wx::wxSTC_FOLDFLAG_LINEAFTER_CONTRACTED );

			# Activate
			$self->SetProperty( 'fold' => 1 );

			Wx::Event::EVT_STC_MARGINCLICK(
				$self, -1,
				sub {
					my ( $editor, $event ) = @_;
					if ( $event->GetMargin == 2 ) {
						my $line_clicked  = $editor->LineFromPosition( $event->GetPosition );
						my $level_clicked = $editor->GetFoldLevel($line_clicked);

						# TO DO check this (cf. ~/contrib/samples/stc/edit.cpp from wxWidgets)
						#if ( $level_clicked && wxSTC_FOLDLEVELHEADERFLAG) > 0) {
						$editor->ToggleFold($line_clicked);

						#}
					}
				}
			);
		} else {
			$self->SetMarginSensitive( 2, 0 );
			$self->SetMarginWidth( 2, 0 );

			# Deactivate
			$self->SetProperty( 'fold' => 1 );
			$self->unfold_all;
		}

		return;
		}
		if Padre::Feature::FOLDING;

	*fold_this = sub {
		my $self        = shift;
		my $currentLine = $self->GetCurrentLine;

		unless ( $self->GetFoldExpanded($currentLine) ) {
			$self->ToggleFold($currentLine);
			return;
		}

		while ( $currentLine >= 0 ) {
			if ( ( my $parentLine = $self->GetFoldParent($currentLine) ) > 0 ) {
				$self->ToggleFold($parentLine);
				return;
			} else {
				$currentLine--;
			}
		}

		return;
		}
		if Padre::Feature::FOLDING;

	*fold_all = sub {
		my $self        = shift;
		my $lineCount   = $self->GetLineCount;
		my $currentLine = $lineCount;

		while ( $currentLine >= 0 ) {
			if ( ( my $parentLine = $self->GetFoldParent($currentLine) ) > 0 ) {
				if ( $self->GetFoldExpanded($parentLine) ) {
					$self->ToggleFold($parentLine);
					$currentLine = $parentLine;
				} else {
					$currentLine--;
				}
			} else {
				$currentLine--;
			}
		}

		return;
		}
		if Padre::Feature::FOLDING;

	*unfold_all = sub {
		my $self        = shift;
		my $lineCount   = $self->GetLineCount;
		my $currentLine = 0;

		while ( $currentLine <= $lineCount ) {
			if ( !$self->GetFoldExpanded($currentLine) ) {
				$self->ToggleFold($currentLine);
			}
			$currentLine++;
		}

		return;
		}
		if Padre::Feature::FOLDING;

	*fold_pod = sub {
		my $self        = shift;
		my $currentLine = 0;
		my $lastLine    = $self->GetLineCount;

		while ( $currentLine <= $lastLine ) {
			if ( $self->GetLine($currentLine) =~ /^=(pod|head)/ ) {
				if ( $self->GetFoldExpanded($currentLine) ) {
					$self->ToggleFold($currentLine);
					my $foldLevel = $self->GetFoldLevel($currentLine);
					$currentLine = $self->GetLastChild( $currentLine, $foldLevel );
				}
				$currentLine++;
			} else {
				$currentLine++;
			}
		}

		return;
		}
		if Padre::Feature::FOLDING;
}





######################################################################
# Cursor Memory

BEGIN {

	#
	# $doc->store_cursor_position
	#
	# store document's current cursor position in padre's db.
	# no params, no return value.
	#
	*store_cursor_position = sub {
		my $self     = shift;
		my $document = $self->{Document} or return;
		my $file     = $document->{file} or return;
		Padre::DB::LastPositionInFile->set_last_pos(
			$file->filename,
			$self->GetCurrentPos,
		);
		}
		if Padre::Feature::CURSORMEMORY;

	#
	# $doc->restore_cursor_position
	#
	# restore document's cursor position from padre's db.
	# no params, no return value.
	#
	*restore_cursor_position = sub {
		my $self     = shift;
		my $document = $self->{Document} or return;
		my $file     = $document->{file} or return;
		my $filename = $file->filename;
		my $position = Padre::DB::LastPositionInFile->get_last_pos($filename);
		return unless defined $position;
		$self->SetCurrentPos($position);
		$self->SetSelection( $position, $position );
		}
		if Padre::Feature::CURSORMEMORY;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
