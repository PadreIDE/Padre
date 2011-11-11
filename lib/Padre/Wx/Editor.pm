package Padre::Wx::Editor;

use 5.008;
use strict;
use warnings;
use Time::HiRes               ();
use Wx::Scintilla        0.34 ();
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

our $VERSION    = '0.92';
our $COMPATIBLE = '0.91';
our @ISA        = (
	'Padre::Wx::Role::Main',
	'Padre::Wx::Role::Dwell',
	'Wx::Scintilla::TextCtrl',
);

use constant {

	# Convenience colour constants
	# NOTE: DO NOT USE "orange" string since it is actually red on win32
	ORANGE     => Wx::Colour->new( 255, 165, 0 ),
	RED        => Wx::Colour->new("red"),
	GREEN      => Wx::Colour->new("green"),
	BLUE       => Wx::Colour->new("blue"),
	YELLOW     => Wx::Colour->new("yellow"),
	DARK_GREEN => Wx::Colour->new( 0x00, 0x90, 0x00 ),
	LIGHT_RED  => Wx::Colour->new( 0xFF, 0xA0, 0xB4 ),
	LIGHT_BLUE => Wx::Colour->new( 0xA0, 0xC8, 0xFF ),
	GRAY       => Wx::Colour->new('gray'),
};

# End-Of-Line modes:
# MAC is actually Mac classic.
# MAC OS X and later uses UNIX EOLs
#
# Please note that WIN32 is the API. DO NOT change it to that :)
#
# Initialize variables after loading either Wx::Scintilla or Wx::STC
my %WXEOL = (
	WIN  => Wx::Scintilla::SC_EOL_CRLF,
	MAC  => Wx::Scintilla::SC_EOL_CR,
	UNIX => Wx::Scintilla::SC_EOL_LF,
);





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
	my $lock = $main->lock( 'UPDATE', 'refresh_windowlist' );
	my $self = $class->SUPER::new($parent);

	# Hide the editor as quickly as possible so it isn't
	# visible during the period we are setting it up.
	$self->Hide;

	# This is supposed to be Wx::Scintilla::CP_UTF8
	# and Wx::wxUNICODE or wxUSE_UNICODE should be on
	$self->SetCodePage(65001);

	# Code always lays out left to right
	if ( $self->can('SetLayoutDirection') ) {
		$self->SetLayoutDirection(Wx::Layout_LeftToRight);
	}

	# Allow scrolling past the end of the document for those of us
	# used to Ultraedit where you can type into a relaxing clear space.
	$self->SetEndAtLastLine(0);

	# Integration with the rest of Padre
	$self->SetDropTarget( Padre::Wx::FileDropTarget->new($main) );

	# Set the code margins a little larger than the default.
	# This seems to noticably reduce eye strain.
	$self->SetMarginLeft(2);
	$self->SetMarginRight(0);

	# Clear out all the other margins
	$self->SetMarginWidth( Padre::Constant::MARGIN_LINE,   0 );
	$self->SetMarginWidth( Padre::Constant::MARGIN_MARKER, 0 );
	$self->SetMarginWidth( Padre::Constant::MARGIN_FOLD,   0 );

	# Set the margin types (whether we show them or not)
	$self->SetMarginType(
		Padre::Constant::MARGIN_LINE,
		Wx::Scintilla::SC_MARGIN_NUMBER,
	);
	$self->SetMarginType(
		Padre::Constant::MARGIN_MARKER,
		Wx::Scintilla::SC_MARGIN_SYMBOL,
	);
	if ( Padre::Feature::FOLDING ) {
		$self->SetMarginType(
			Padre::Constant::MARGIN_FOLD,
			Wx::Scintilla::SC_MARGIN_SYMBOL,
		);
		$self->SetMarginMask(
			Padre::Constant::MARGIN_FOLD,
			Wx::Scintilla::SC_MASK_FOLDERS,
		);
	}

	# Set up all of the default markers
	$self->MarkerDefine(
		Padre::Constant::MARKER_ERROR,
		Wx::Scintilla::SC_MARK_SMALLRECT,
		RED,
		RED,
	);
	$self->MarkerDefine(
		Padre::Constant::MARKER_WARN,
		Wx::Scintilla::SC_MARK_SMALLRECT,
		ORANGE,
		ORANGE,
	);
	$self->MarkerDefine(
		Padre::Constant::MARKER_LOCATION,
		Wx::Scintilla::SC_MARK_SMALLRECT,
		GREEN,
		GREEN,
	);
	$self->MarkerDefine(
		Padre::Constant::MARKER_BREAKPOINT,
		# Wx::Scintilla::MARK_SMALLRECT,
		Wx::Scintilla::SC_MARK_DOTDOTDOT,
		BLUE,
		BLUE,
	);	
	$self->MarkerDefine(
		Padre::Constant::MARKER_NOT_BREAKABLE,
		Wx::Scintilla::SC_MARK_DOTDOTDOT,
		GRAY,
		GRAY,
	);
	$self->MarkerDefine(
		Padre::Constant::MARKER_ADDED,
		Wx::Scintilla::SC_MARK_PLUS,
		DARK_GREEN,
		DARK_GREEN,
	);
	$self->MarkerDefine(
		Padre::Constant::MARKER_CHANGED,
		Wx::Scintilla::SC_MARK_ARROW,
		LIGHT_BLUE,
		LIGHT_BLUE,
	);
	$self->MarkerDefine(
		Padre::Constant::MARKER_DELETED,
		Wx::Scintilla::SC_MARK_MINUS,
		LIGHT_RED,
		LIGHT_RED,
	);

	# CTRL-L or line cut should only work when there is no empty line
	# This prevents the accidental destruction of the clipboard
	$self->CmdKeyClear( ord('L'), Wx::Scintilla::SCMOD_CTRL );

	# Disable CTRL keypad -/+. These seem to emit wrong scan codes
	# on some laptop keyboards. (e.g. CTRL-Caps lock is the same as CTRL -)
	# Please see bug #790
	$self->CmdKeyClear( Wx::Scintilla::SCK_SUBTRACT, Wx::Scintilla::SCMOD_CTRL );
	$self->CmdKeyClear( Wx::Scintilla::SCK_ADD,      Wx::Scintilla::SCMOD_CTRL );

	# Setup the editor indicators which we will use in smart, warning and error highlighting
	# Indicator #0: Green round box indicator for smart highlighting
	$self->IndicatorSetStyle( Padre::Constant::INDICATOR_SMART_HIGHLIGHT, Wx::Scintilla::INDIC_ROUNDBOX );

	# Indicator #1, Orange squiggle for warning highlighting
	$self->IndicatorSetForeground( Padre::Constant::INDICATOR_WARNING, ORANGE );
	$self->IndicatorSetStyle( Padre::Constant::INDICATOR_WARNING, Wx::Scintilla::INDIC_SQUIGGLE );

	# Indicator #2, Red squiggle for error highlighting
	$self->IndicatorSetForeground( Padre::Constant::INDICATOR_ERROR, RED );
	$self->IndicatorSetStyle( Padre::Constant::INDICATOR_ERROR, Wx::Scintilla::INDIC_SQUIGGLE );

	# Indicator #3, underline for mouse-clickable tokens
	$self->IndicatorSetForeground( Padre::Constant::INDICATOR_UNDERLINE, BLUE );
	$self->IndicatorSetStyle( Padre::Constant::INDICATOR_UNDERLINE, Wx::Scintilla::INDIC_PLAIN );

	# Basic event bindings
	Wx::Event::EVT_SET_FOCUS(  $self, sub { shift->on_set_focus(@_)    } );
	Wx::Event::EVT_KILL_FOCUS( $self, sub { shift->on_kill_focus(@_)   } );
	Wx::Event::EVT_KEY_UP(     $self, sub { shift->on_key_up(@_)       } );
	Wx::Event::EVT_CHAR(       $self, sub { shift->on_char(@_)         } );
	Wx::Event::EVT_MOTION(     $self, sub { shift->on_mouse_moving(@_) } );
	Wx::Event::EVT_MOUSEWHEEL( $self, sub { shift->on_mousewheel(@_)   } );
	Wx::Event::EVT_LEFT_DOWN(  $self, sub { shift->on_left_down(@_)    } );
	Wx::Event::EVT_LEFT_UP(    $self, sub { shift->on_left_up(@_)      } );
	Wx::Event::EVT_MIDDLE_UP(  $self, sub { shift->on_middle_up(@_)    } );

	# FIXME Find out why EVT_CONTEXT_MENU doesn't work on Ubuntu
	if ( Padre::Constant::UNIX ) {
		Wx::Event::EVT_RIGHT_DOWN(
			$self,
			sub {
				shift->on_context_menu(@_);
			},
		);
	} else {
		Wx::Event::EVT_CONTEXT_MENU(
			$self,
			sub {
				shift->on_context_menu(@_);
			},
		);
	}

	# Scintilla specific event bindings
	Wx::Event::EVT_STC_DOUBLECLICK(
		$self, -1,
		sub {
			shift->on_left_double(@_);
		},
	);

	# Capture change events that result in an actual change to the text
	# of the document, so we can refire content-dependent editor tools.
	$self->SetModEventMask(
		Wx::Scintilla::SC_PERFORMED_USER | Wx::Scintilla::SC_PERFORMED_UNDO | Wx::Scintilla::SC_PERFORMED_REDO | Wx::Scintilla::SC_MOD_INSERTTEXT
			| Wx::Scintilla::SC_MOD_DELETETEXT
	);
	Wx::Event::EVT_STC_CHANGE(
		$self, $self,
		sub {
			shift->on_change(@_);
		},
	);

	# Smart highlighting:
	# Selecting a word or small block of text causes all other occurrences to be highlighted
	# with a round box around each of them
	$self->{styles} = [];

	# Apply settings based on configuration
	# TO DO: Make this suck less (because it really does suck a lot)
	$self->setup_common;

	return $self;
}





######################################################################
# Event Handlers

# When the focus is received by the editor
sub on_set_focus {
	TRACE() if DEBUG;
	my $self     = shift;
	my $event    = shift;
	my $document = $self->{Document} or return;
	TRACE( "Focus received file:" . $document->get_title ) if DEBUG;

	# Update the line number width
	$self->refresh_line_numbers;

	# NOTE: The editor focus event fires a LOT, even for trivial things
	# like changing focus to another application and immediately back again,
	# or switching between tools in Padre.
	# Try to avoid refreshing here, it is an excessive waste of resources.
	# Instead, put them in the events that ACTUALLY change application
	# state.

	# TO DO
	# This is called even if the mouse is moved away from padre and back
	# again we should restrict some of the updates to cases when we switch
	# from one file to another.
	if ( $self->needs_manual_colorize ) {
		TRACE("needs_manual_colorize") if DEBUG;
		my $lock  = $self->lock_update;
		my $lexer = $self->GetLexer;
		if ( $lexer == Wx::Scintilla::SCLEX_CONTAINER ) {
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

# Called when a key is released
sub on_key_up {
	my $self  = shift;
	my $event = shift;

	# The new behavior for a non-destructive CTRL-L
	if ( $event->GetKeyCode == ord('L') and $event->ControlDown ) {
		my $line = $self->GetLine( $self->GetCurrentLine );
		if ( $line !~ /^\s*$/ ) {

			# Only cut on non-blank lines
			$self->LineCut;
		} else {

			# Otherwise delete the line
			$self->LineDelete;
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
	my $self  = shift;
	my $event = shift;

	# Hide the smart highlight when a character is added or changed
	# in the editor
	$self->smart_highlight_hide;

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
		$self->refresh_line_numbers;
		$main->refresh_functions;
		$main->refresh_outline;
		$main->refresh_syntaxcheck;
		$main->refresh_todo;
		$main->refresh_diff;
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

	if ( Wx::GTK and defined $text and $text ne '' ) {

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
		Wx::TheClipboard->UsePrimarySelection(1);
	}

	if ( Padre::Constant::WIN32 or not $config->mid_button_paste ) {
		$self->Paste;
	}

	my $doc = $self->{Document};
	if ( $doc->can('event_on_middle_up') ) {
		$doc->event_on_middle_up( $self, $event );
	}

	if ( $config->mid_button_paste ) {
		Wx::TheClipboard->UsePrimarySelection(0);
		$event->Skip(1);
	} else {
		$event->Skip(0);
	}
}

sub on_context_menu {
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

# An alternative to GetWrapMode that returns the mode in text form,
# primarily so that the view menu does not need to load Wx::Scintilla
# for access to the constants
sub get_wrap_mode {
	my $self = shift;
	my $mode = $self->GetWrapMode;
	return 'WORD' if $mode == Wx::Scintilla::SC_WRAP_WORD;
	return 'CHAR' if $mode == Wx::Scintilla::SC_WRAP_CHAR;
	return 'NONE';
}

# Fill the editor with the document
sub set_document {
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

sub SetLexer {
	my $self  = shift;
	my $lexer = shift;
	if ( Params::Util::_NUMBER($lexer) ) {
		return $self->SUPER::SetLexer($lexer);
	}
	if ( defined Params::Util::_STRING($lexer) ) {
		require Padre::MimeTypes;
		$lexer = Padre::MimeTypes->get_lexer($lexer);
		return $self->SUPER::SetLexer($lexer);
	}
	return;
}

sub StyleAllForeground {
	my $self   = shift;
	my $colour = shift;
	foreach my $i ( 0 .. 31 ) {
		$self->StyleSetBackground( $i, $colour );
	}
	return;
}

sub StyleAllBackground {
	my $self   = shift;
	my $colour = shift;
	foreach my $i ( 0 .. 31 ) {
		$self->StyleSetBackground( $i, $colour );
	}
	return;
}

# Allow projects to override editor preferences
sub config {
	my $self    = shift;
	my $project = $self->current->project;
	return $project->config if $project;
	return $self->SUPER::config(@_);
}

# Apply global configuration settings to the editor
sub setup_common {
	my $self   = shift;
	my $config = $self->config;

	# Apply various settings that largely map directly
	$self->SetCaretPeriod( $config->editor_cursor_blink );
	$self->SetCaretLineVisible( $config->editor_currentline );
	$self->SetViewEOL( $config->editor_eol );
	$self->SetViewWhiteSpace( $config->editor_whitespace );
	$self->show_line_numbers( $config->editor_linenumbers );
	$self->SetIndentationGuides( $config->editor_indentationguides );

	# Enable or disable word wrapping
	if ( $config->editor_wordwrap ) {
		$self->SetWrapMode(Wx::Scintilla::SC_WRAP_WORD);
	} else {
		$self->SetWrapMode(Wx::Scintilla::SC_WRAP_NONE);
	}

	# Enable or disable the right hand margin guideline
	if ( $config->editor_right_margin_enable ) {
		$self->SetEdgeColumn( $config->editor_right_margin_column );
		$self->SetEdgeMode(Wx::Scintilla::EDGE_LINE);
	} else {
		$self->SetEdgeMode(Wx::Scintilla::EDGE_NONE);
	}

	# Set the font
	my $font = Wx::Font->new( 10, Wx::TELETYPE, Wx::NORMAL, Wx::NORMAL );
	if ( defined $config->editor_font and length $config->editor_font > 0 ) {
		$font->SetNativeFontInfoUserDesc( $config->editor_font );
	}
	$self->SetFont($font);
	$self->StyleSetFont( Wx::Scintilla::STYLE_DEFAULT, $font );

	# Enable the symbol margin if anything needs it
	if ( $config->main_syntaxcheck or $config->feature_document_diffs ) {
		if ( $self->GetMarginWidth(1) == 0 ) {
			# Set margin 1 as a 16 pixel symbol margin
			$self->SetMarginWidth( Padre::Constant::MARGIN_MARKER, 16 );
		}
	}

	return;
}

# Most of this should be read from some external files
# but for now we use this if statement
sub setup_document {
	my $self     = shift;
	my $config   = $self->config;
	my $document = $self->{Document};

	# Configure lexing for the editor based on the document type
	if ($document) {
		$self->SetLexer( $document->lexer );
		$self->SetStyleBits( $self->GetStyleBitsNeeded );
		$self->SetWordChars( $document->scintilla_word_chars );

		# Set all the lexer keywords lists that the document provides
		my $key_words = $document->scintilla_key_words;
		for my $i ( 0 .. $#$key_words ) {
			$self->SetKeyWords( $i, join( ' ', @{ $key_words->[$i] } ) );
		}

		# Setup indenting
		my $indent = $document->get_indentation_style;
		$self->SetTabWidth( $indent->{tabwidth} );  # Tab char width
		$self->SetIndent( $indent->{indentwidth} ); # Indent columns
		$self->SetUseTabs( $indent->{use_tabs} );

		# Enable or disable folding (if folding is turned on)
		# Please enable it when the lexer is changed because it is
		# the one that creates the code folding for that particular
		# document
		$self->show_folding( $config->editor_folding )
			if Padre::Feature::FOLDING;
	} else {
		$self->SetWordChars('');
	}

	# Apply the current style to the editor
	$self->main->theme->apply($self);

	# When we apply the style, refresh the line number margin in case
	# the changed style results in a different size font.
	$self->refresh_line_numbers;

	return;
}





######################################################################
# General Methods

# Recalculate the line number margins whenever we change the zoom level
sub SetZoom {
	my $self = shift;
	my @rv   = $self->SUPER::SetZoom(@_);
	$self->refresh_line_numbers;
	return @rv;
}

# convenience methods
# return the character at a given position as a perl string
sub get_character_at {
	return chr $_[0]->GetCharAt( $_[1] );
}

# Error Message
sub error {
	my $self = shift;
	my $text = shift;
	Wx::MessageBox(
		$text,
		Wx::gettext("Error"),
		Wx::OK,
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
	$self->BraceHighlight( Wx::Scintilla::INVALID_POSITION, Wx::Scintilla::INVALID_POSITION );
	if ($previous_expr_hiliting_style) {
		$self->apply_style($previous_expr_hiliting_style);
		$previous_expr_hiliting_style = undef;
	}

	my $pos1          = $self->GetCurrentPos;
	my $info1         = $self->get_brace_info($pos1) or return;
	my ($actual_pos1) = @$info1;

	my $actual_pos2 = $self->BraceMatch($actual_pos1);

	return if $actual_pos2 == Wx::Scintilla::INVALID_POSITION; #Wx::Scintilla::INVALID_POSITION  #????

	$self->BraceHighlight( $actual_pos1, $actual_pos2 );

	if ($expression_highlighting) {
		my $pos2 = $self->find_matching_brace($pos1) or return;
		my %style = (
			start => $pos1 < $pos2 ? $pos1 : $pos2,
			len => abs( $pos1 - $pos2 ), style => Wx::Scintilla::STYLE_DEFAULT
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
	return if $actual_pos2 == Wx::Scintilla::INVALID_POSITION;
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

sub refresh_line_numbers {
	my $self = shift;
	$self->show_line_numbers(
		$self->config->editor_linenumbers
	);
}

# Calculate the maximum possible width, and set to that plus a few pixels.
# We don't allow any excess space for future growth as we anticipate calling
# this function relatively frequently.
sub show_line_numbers {
	my $self  = shift;
	my $on    = shift;
	my $width = 0;

	if ($on) {
		$width  = $self->TextWidth(
			Wx::Scintilla::STYLE_LINENUMBER,
			"m" x List::Util::max( 2, length $self->GetLineCount )
		) + 5; # 5 pixel left "margin of the margin
	}

	$self->SetMarginWidth(
		Padre::Constant::MARGIN_LINE,
		$width,
	);
}

sub show_calltip {
	my $self   = shift;
	my $config = $self->config;
	return unless $config->editor_calltips;

	my $pos    = $self->GetCurrentPos;
	my $line   = $self->LineFromPosition($pos);
	my $first  = $self->PositionFromLine($line);
	my $prefix = $self->GetTextRange( $first, $pos ); # line from beginning to current position
	$self->CallTipCancel if $self->CallTipActive;

	my $doc      = $self->current->document or return;
	my $keywords = $doc->get_calltip_keywords;
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
	if ( $eol_mode eq Wx::Scintilla::SC_EOL_CRLF ) {
		$to = $CRLF;
	} elsif ( $eol_mode eq Wx::Scintilla::SC_EOL_LF ) {
		$to = $LF;
	} else {

		#must be Wx::Scintilla::EOL_CR
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

	Wx::TheClipboard->Open;
	Wx::TheClipboard->UsePrimarySelection($clipboard)
		if $config->mid_button_paste;
	Wx::TheClipboard->SetData( Wx::TextDataObject->new($text) );
	Wx::TheClipboard->Close;

	return;
}

sub get_text_from_clipboard {
	my $self = shift;
	my $text = '';
	Wx::TheClipboard->Open;
	if ( Wx::TheClipboard->IsSupported(Wx::DF_TEXT) ) {
		my $data = Wx::TextDataObject->new;
		if ( Wx::TheClipboard->GetData($data) ) {
			$text = $data->GetText if defined $data;
		}
	}
	if ( $text eq $self->GetSelectedText ) {
		$text = $self->{Clipboard_Old};
	}

	Wx::TheClipboard->Close;
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

# Default (fast) method for deleting all leading spaces
sub delete_leading_spaces {
	my $self    = shift;
	my $lines   = $self->GetLineCount;
	my $changed = 0;

	foreach my $i ( 0 .. $self->GetLineCount ) {
		my $line = $self->GetLine($i);
		unless ( $line =~ /\A([ \t]+)/ ) {
			next;
		}
		my $start = $self->PositionFromLine($i);
		$self->SetTargetStart($start);
		$self->SetTargetEnd( $start + length $1 );
		$self->BeginUndoAction unless $changed++;
		$self->ReplaceTarget('');
	}
	$self->EndUndoAction if $changed;

	return $changed;
}

# Default (fast) method for deleting all trailing spaces
sub delete_trailing_spaces {
	my $self    = shift;
	my $lines   = $self->GetLineCount;
	my $changed = 0;

	foreach my $i ( 0 .. $self->GetLineCount ) {
		my $line = $self->GetLine($i);
		unless ( $line =~ /\A(.*?)([ \t]+)([\015\012]*)\z/ ) {
			next;
		}
		my $start = $self->PositionFromLine($i) + length $1;
		$self->SetTargetStart($start);
		$self->SetTargetEnd( $start + length $2 );
		$self->BeginUndoAction unless $changed++;
		$self->ReplaceTarget('');
	}
	$self->EndUndoAction if $changed;

	return $changed;
}

sub vertically_align {
	my $self = shift;

	# Get the selected lines
	my $begin = $self->LineFromPosition( $self->GetSelectionStart );
	my $end   = $self->LineFromPosition( $self->GetSelectionEnd );
	if ( $begin == $end ) {
		$self->error( Wx::gettext("You must select a range of lines") );
		return;
	}
	my @line = ( $begin .. $end );
	my @text = ();
	foreach (@line) {
		my $x = $self->PositionFromLine($_);
		my $y = $self->GetLineEndPosition($_);
		push @text, $self->GetTextRange( $x, $y );
	}

	# Get the align character from the selection start
	# (which must be a non-whitespace non-word character)
	my $start = $self->GetSelectionStart;
	my $c = $self->GetTextRange( $start, $start + 1 );
	unless ( defined $c and $c =~ /^[^\s\w]$/ ) {
		$self->error( Wx::gettext("First character of selection must be a non-word character to align") );
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
	$self->BeginUndoAction;
	foreach ( 0 .. $#line ) {
		next unless $position[$_];
		my $spaces = $longest - $position[$_]->[0] - $position[$_]->[1] + 1;
		if ( $_ == 0 ) {
			$start = $start + $spaces;
		}

		my $insert = $self->PositionFromLine( $line[$_] ) + $position[$_]->[0] + 1;
		if ( $spaces > 0 ) {
			$self->SetTargetStart($insert);
			$self->SetTargetEnd($insert);
			$self->ReplaceTarget( ' ' x $spaces );
		} elsif ( $spaces < 0 ) {
			$self->SetTargetStart($insert);
			$self->SetTargetEnd( $insert - $spaces );
			$self->ReplaceTarget('');
		}
	}
	$self->EndUndoAction;

	# Move the selection to the new position
	$self->SetSelection( $start, $start );

	return;
}

sub needs_manual_colorize {
	if ( defined $_[1] ) {
		$_[0]->{needs_manual_colorize} = $_[1];
	}
	return $_[0]->{needs_manual_colorize};
}





######################################################################
# Highlighting

# The main purpose of these manual highlighting methods is to prevent
# the document classes from having to use Wx code directly.

sub manual_highlight_show {
	my $self       = shift;
	my $position   = shift;
	my $characters = shift;
	$self->SetIndicatorCurrent(Padre::Constant::INDICATOR_UNDERLINE);
	$self->IndicatorFillRange( $position, $characters );
	return 1;
}

sub manual_highlight_hide {
	my $self       = shift;
	my $position   = shift;
	my $characters = shift;
	$self->SetIndicatorCurrent(Padre::Constant::INDICATOR_UNDERLINE);
	$self->IndicatorClearRange( $position, $characters );
}

sub smart_highlight_show {
	my $self             = shift;
	my $selection        = $self->GetSelectedText;
	my $selection_length = length $selection;

	# Zero length selection should be ignored
	return if $selection_length == 0;

	# Whitespace should be ignored
	return if $selection =~ /^\s+$/;

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
				};
		}
	}

	# smart highlight if there are more than one occurrence...
	if ( scalar @{ $self->{styles} } > 1 ) {
		foreach my $style ( @{ $self->{styles} } ) {
			$self->SetIndicatorCurrent(Padre::Constant::INDICATOR_SMART_HIGHLIGHT);
			$self->IndicatorFillRange( $style->{start}, $style->{len} );
		}
	}

}

sub smart_highlight_hide {
	my $self = shift;

	my @styles = @{ $self->{styles} };
	if ( scalar @styles ) {

		# Clear indicators for all available text
		$self->SetIndicatorCurrent(Padre::Constant::INDICATOR_SMART_HIGHLIGHT);
		my $text_length = $self->GetTextLength;
		$self->IndicatorClearRange( 0, $text_length ) if $text_length > 0;

		# Clear old styles
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
			 # This one needs to be mouse-aware.
			$self->SetMarginSensitive(
				Padre::Constant::MARGIN_FOLD,
				1,
			);
			$self->SetMarginWidth(
				Padre::Constant::MARGIN_FOLD,
				16,
			);

			# Define folding markers. The colours are really dummy
			# as the themes will override them
			my $w = Wx::Colour->new("white");
			my $b = Wx::Colour->new("black");
			$self->MarkerDefine( Wx::Scintilla::SC_MARKNUM_FOLDEREND,     Wx::Scintilla::SC_MARK_BOXPLUSCONNECTED,  $w, $b );
			$self->MarkerDefine( Wx::Scintilla::SC_MARKNUM_FOLDEROPENMID, Wx::Scintilla::SC_MARK_BOXMINUSCONNECTED, $w, $b );
			$self->MarkerDefine( Wx::Scintilla::SC_MARKNUM_FOLDERMIDTAIL, Wx::Scintilla::SC_MARK_TCORNER,           $w, $b );
			$self->MarkerDefine( Wx::Scintilla::SC_MARKNUM_FOLDERTAIL,    Wx::Scintilla::SC_MARK_LCORNER,           $w, $b );
			$self->MarkerDefine( Wx::Scintilla::SC_MARKNUM_FOLDERSUB,     Wx::Scintilla::SC_MARK_VLINE,             $w, $b );
			$self->MarkerDefine( Wx::Scintilla::SC_MARKNUM_FOLDER,        Wx::Scintilla::SC_MARK_BOXPLUS,           $w, $b );
			$self->MarkerDefine( Wx::Scintilla::SC_MARKNUM_FOLDEROPEN,    Wx::Scintilla::SC_MARK_BOXMINUS,          $w, $b );

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
						#if ( $level_clicked && Wx::Scintilla::FOLDLEVELHEADERFLAG) > 0) {
						$editor->ToggleFold($line_clicked);

						#}
					}
				}
			);
		} else {
			$self->SetMarginSensitive(
				Padre::Constant::MARGIN_FOLD,
				0,
			);
			$self->SetMarginWidth(
				Padre::Constant::MARGIN_FOLD,
				0,
			);

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
