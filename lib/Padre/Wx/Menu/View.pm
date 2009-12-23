package Padre::Wx::Menu::View;

# Fully encapsulated View menu

use 5.008;
use strict;
use warnings;
use File::Glob      ();
use Padre::Constant ();
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Locale   ();

our $VERSION = '0.52';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = Padre->ide->config;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Can the user move stuff around
	$self->{lockinterface} = $self->add_checked_menu_item(
		$self,
		name       => 'view.lockinterface',
		label      => Wx::gettext('Lock User Interface'),
		comment    => Wx::gettext('Allow the user to move around some of the windows'),
		menu_event => sub {
			$_[0]->on_toggle_lockinterface( $_[1] );
		},
	);

	$self->AppendSeparator;

	# Show or hide GUI elements
	$self->{output} = $self->add_checked_menu_item(
		$self,
		name       => 'view.output',
		label      => Wx::gettext('Show Output'),
		comment    => Wx::gettext('Show the window displaying the standard output and standar error of the running scripts'),
		menu_event => sub {
			$_[0]->show_output( $_[1]->IsChecked );
		},
	);

	$self->{functions} = $self->add_checked_menu_item(
		$self,
		name       => 'view.functions',
		label      => Wx::gettext('Show Functions'),
		comment    => Wx::gettext('Show a window listing all the functions in the current document'),
		menu_event => sub {
			if ( $_[1]->IsChecked ) {
				$_[0]->refresh_functions( $_[0]->current );
				$_[0]->show_functions(1);
			} else {
				$_[0]->show_functions(0);
			}
		},
	);

	# Show or hide GUI elements
	$self->{outline} = $self->add_checked_menu_item(
		$self,
		name       => 'view.outline',
		label      => Wx::gettext('Show Outline'),
		comment    => Wx::gettext('Show a window listing all the parts of the current file (functions, pragmas, modules)'),
		menu_event => sub {
			$_[0]->show_outline( $_[1]->IsChecked );
		},
	);

	$self->{directory} = $self->add_checked_menu_item(
		$self,
		name       => 'view.directory',
		label      => Wx::gettext('Show Directory Tree'),
		comment    => Wx::gettext('Show a window with a directory browser of the current project'),
		menu_event => sub {
			$_[0]->show_directory( $_[1]->IsChecked );
		},
	);

	$self->{show_syntaxcheck} = $self->add_checked_menu_item(
		$self,
		name       => 'view.show_syntaxcheck',
		label      => Wx::gettext('Show Syntax Check'),
		comment    => Wx::gettext('Turn on syntax checking of the current document and show output in a window'),
		menu_event => sub {
			$_[0]->on_toggle_syntax_check( $_[1] );
		},
	);

	$self->{show_errorlist} = $self->add_checked_menu_item(
		$self,
		name       => 'view.show_errorlist',
		label      => Wx::gettext('Show Error List'),
		comment    => Wx::gettext('Show the list of errors received during execution of a script'),
		menu_event => sub {
			$_[0]->on_toggle_errorlist( $_[1] );
		},
	);

	$self->{statusbar} = $self->add_checked_menu_item(
		$self,
		name       => 'view.statusbar',
		label      => Wx::gettext('Show Status Bar'),
		comment    => Wx::gettext('Show/hide the status bar at the bottom of the screen'),
		menu_event => sub {
			$_[0]->on_toggle_statusbar( $_[1] );
		},
	);

	$self->{toolbar} = $self->add_checked_menu_item(
		$self,
		name       => 'view.toolbar',
		label      => Wx::gettext('Show Toolbar'),
		comment    => Wx::gettext('Show/hide the toolbar at the top of the editor'),
		menu_event => sub {
			$_[0]->on_toggle_toolbar( $_[1] );
		},
	);

	$self->AppendSeparator;

	# View as (Highlighting File Type)
	$self->{view_as_highlighting} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("View Document As..."),
		$self->{view_as_highlighting}
	);

	my %mimes = Padre::Document::menu_view_mimes();
	foreach my $name ( sort keys %mimes ) {
		my $label = $name;
		$label =~ s/^\d+//;
		my $tag = "view.view_as" . lc $label;
		$tag =~ s/\s/_/g;
		$self->add_radio_menu_item(
			$self->{view_as_highlighting},
			name       => $tag,
			label      => $label,
			comment    => sprintf(Wx::gettext('Switch document type to %s'), $label),
			menu_event => sub { $_[0]->set_mimetype( $mimes{$name} ) },
		);
	}

	$self->AppendSeparator;

	# Editor Functionality
	$self->{lines} = $self->add_checked_menu_item(
		$self,
		name       => 'view.lines',
		label      => Wx::gettext('Show Line Numbers'),
		comment    => Wx::gettext('Show/hide the line numbers of all the documents on the left side of the window'),
		menu_event => sub {
			$_[0]->on_toggle_line_numbers( $_[1] );
		},
	);

	$self->{folding} = $self->add_checked_menu_item(
		$self,
		name       => 'view.folding',
		label      => Wx::gettext('Show Code Folding'),
		comment    => Wx::gettext('Show/hide a vertical line on the left hand side of the window to allow folding rows'),
		menu_event => sub {
			$_[0]->on_toggle_code_folding( $_[1] );
		},
	);

	$self->{show_calltips} = $self->add_checked_menu_item(
		$self,
		name       => 'view.show_calltips',
		label      => Wx::gettext('Show Call Tips'),
		comment    => Wx::gettext('When typing in functions allow showing short examples of the function'),
		menu_event => sub {
			$_[0]->config->set(
				'editor_calltips',
				$_[1]->IsChecked ? 1 : 0,
			);
			$_[0]->config->write;
		},
	);

	$self->{currentline} = $self->add_checked_menu_item(
		$self,
		name       => 'view.currentline',
		label      => Wx::gettext('Show Current Line'),
		comment    => Wx::gettext('Highlight the line where the cursor is'),
		menu_event => sub {
			$_[0]->on_toggle_currentline( $_[1] );
		},
	);

	$self->{rightmargin} = $self->add_checked_menu_item(
		$self,
		name       => 'view.rightmargin',
		label      => Wx::gettext('Show Right Margin'),
		comment    => Wx::gettext('Show a vertical line indicating the right margin'),
		menu_event => sub {
			$_[0]->on_toggle_right_margin( $_[1] );
		},
	);

	$self->AppendSeparator;

	# Editor Whitespace Layout
	$self->{eol} = $self->add_checked_menu_item(
		$self,
		name       => 'view.eol',
		label      => Wx::gettext('Show Newlines'),
		comment    => Wx::gettext('Show/hide the newlines with special character'),
		menu_event => sub {
			$_[0]->on_toggle_eol( $_[1] );
		},
	);

	$self->{whitespaces} = $self->add_checked_menu_item(
		$self,
		name       => 'view.whitespaces',
		label      => Wx::gettext('Show Whitespaces'),
		comment    => Wx::gettext('Show/hide the tabs and the spaces with special characters'),
		menu_event => sub {
			$_[0]->on_toggle_whitespaces( $_[1] );
		},
	);

	$self->{indentation_guide} = $self->add_checked_menu_item(
		$self,
		name       => 'view.indentation_guide',
		label      => Wx::gettext('Show Indentation Guide'),
		comment    => Wx::gettext('Show/hide vertical bars at every indentation position on the left of the rows'),
		menu_event => sub {
			$_[0]->on_toggle_indentation_guide( $_[1] );
		},
	);

	$self->{word_wrap} = $self->add_checked_menu_item(
		$self,
		name       => 'view.word_wrap',
		label      => Wx::gettext('Word-Wrap'),
		comment    => Wx::gettext('Wrap long lines'),
		menu_event => sub {
			$_[0]->on_word_wrap( $_[1]->IsChecked );
		},
	);

	$self->AppendSeparator;


	# Font Size
	$self->{font_size} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Font Size"),
		$self->{font_size}
	);
	$self->{font_increase} = $self->add_menu_item(
		$self->{font_size},
		name       => 'view.font_increase',
		label      => Wx::gettext('Increase Font Size'),
		comment    => Wx::gettext('Make the letters bigger in the editor window'),
		shortcut   => 'Ctrl-+',
		menu_event => sub {
			$_[0]->zoom(+1);
		},
	);

	$self->{font_decrease} = $self->add_menu_item(
		$self->{font_size},
		name       => 'view.font_decrease',
		label      => Wx::gettext('Decrease Font Size'),
		comment    => Wx::gettext('Make the letters smaller in the editor window'),
		shortcut   => 'Ctrl--',
		menu_event => sub {
			$_[0]->zoom(-1);
		},
	);

	$self->{font_reset} = $self->add_menu_item(
		$self->{font_size},
		name       => 'view.font_reset',
		label      => Wx::gettext('Reset Font Size'),
		comment    => Wx::gettext('Reset the the size of the letters to the default in the editor window'),
		shortcut   => 'Ctrl-0',
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$_[0]->zoom( -1 * $editor->GetZoom );
		},
	);

	if ( $config->func_bookmark ) {

		$self->AppendSeparator;

		# Bookmark Support
		$self->{bookmark_set} = $self->add_menu_item(
			$self,
			name       => 'view.bookmark_set',
			label      => Wx::gettext('Set Bookmark'),
			comment    => Wx::gettext('Create a bookmark in the current file current row'),
			shortcut   => 'Ctrl-B',
			menu_event => sub {
				require Padre::Wx::Dialog::Bookmarks;
				Padre::Wx::Dialog::Bookmarks->set_bookmark( $_[0] );
			},
		);

		$self->{bookmark_goto} = $self->add_menu_item(
			$self,
			name       => 'view.bookmark_goto',
			label      => Wx::gettext('Goto Bookmark'),
			comment    => Wx::gettext('Select a bookmark created earlier and jump to that position'),
			shortcut   => 'Ctrl-Shift-B',
			menu_event => sub {
				require Padre::Wx::Dialog::Bookmarks;
				Padre::Wx::Dialog::Bookmarks->goto_bookmark( $_[0] );
			},
		);

		$self->AppendSeparator;

	}

	# Editor Look and Feel
	$self->{style} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Style"),
		$self->{style}
	);
	my %styles = (
		default   => Wx::gettext('Padre'),
		evening   => Wx::gettext('Evening'),
		night     => Wx::gettext('Night'),
		ultraedit => Wx::gettext('Ultraedit'),
		notepad   => Wx::gettext('Notepad++'),
	);
	my @order = sort { ( $b eq 'default' ) <=> ( $a eq 'default' ) or $styles{$a} cmp $styles{$b} } keys %styles;
	foreach my $name (@order) {
		my $label = $styles{$name};
		my $tag   = "view.view_as_" . lc $label;
		$tag =~ s/\s/_/g;
		my $radio = $self->add_radio_menu_item(
			$self->{style},
			name       => $tag,
			label      => $label,
			comment    => sprintf(Wx::gettext('Switch highlighting colors to %s style'), $label),
			menu_event => sub {
				$_[0]->change_style($name);
			},
		);
		if ( $config->editor_style and $config->editor_style eq $name ) {
			$radio->Check(1);
		}
	}

	my $dir = File::Spec->catdir( Padre::Constant::CONFIG_DIR, 'styles' );
	my @private =
		map { substr( File::Basename::basename($_), 0, -4 ) } File::Glob::glob( File::Spec->catdir( $dir, '*.yml' ) );
	if (@private) {
		$self->{style}->AppendSeparator;
		foreach my $name (@private) {
			my $label = $name;
			my $tag   = "view.view_as_" . lc $label;
			$tag =~ s/\s/_/g;
			my $radio = $self->add_radio_menu_item(
				$self->{style},
				name       => $tag,
				label      => $label,
				comment    => sprintf(Wx::gettext('Switch highlighting colors to %s style'), $label),
				menu_event => sub {
					$_[0]->change_style( $name, 1 );
				},
			);
			if ( $config->editor_style and $config->editor_style eq $name ) {
				$radio->Check(1);
			}
		}
	}

	# Language Support
	# TO DO: God this is horrible, there has to be a better way
	my $default  = Padre::Locale::system_rfc4646() || 'x-unknown';
	my $current  = Padre::Locale::rfc4646();
	my %language = Padre::Locale::menu_view_languages();

	# Parent Menu
	$self->{language} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Language"),
		$self->{language}
	);

	# Default menu entry
	$self->{language_default} = $self->add_checked_menu_item(
		$self->{language},
		name       => 'view.language_default',
		label      => Wx::gettext('System Default') . " ($default)",
		comment    => sprintf(Wx::gettext('Switch menus to the default %s'), $default),
		menu_event => sub {
			$_[0]->change_locale;
		},
	);
	if ( defined $config->locale and $config->locale eq $default ) {
		$self->{language_default}->Check(1);
	}

	$self->{language}->AppendSeparator;

	foreach my $name ( sort { $language{$a} cmp $language{$b} } keys %language ) {
		my $label = $language{$name};

		# Calculate the tag name before we apply any humour :/
		my $tag = "view.view_as_" . lc $label;
		$tag =~ s/\s/_/g;

		if ( $label eq 'English (United Kingdom)' ) {

			# NOTE: A dose of fun in a mostly boring application.
			# With more Padre developers, more countries, and more
			# people in total British English instead of American
			# English CLEARLY it is a FAR better default for us to
			# use.
			# Because it's something of an in joke to English
			# speakers, non-English localisations do NOT show this.
			$label = "English (New Britstralian)";
		}

		my $radio = $self->add_radio_menu_item(
			$self->{language},
			name       => $tag,
			label      => $label,
			comment    => sprintf(Wx::gettext('Switch menus to %s'), $label),
			menu_event => sub {
				$_[0]->change_locale($name);
			},
		);
		if ( $current eq $name ) {
			$radio->Check(1);
		}
	}

	$self->AppendSeparator;

	# Window Effects
	$self->add_checked_menu_item(
		$self,
		name       => 'view.full_screen',
		label      => Wx::gettext('&Full Screen'),
		comment    => Wx::gettext('Set Padre in full screen mode'),
		shortcut   => 'F11',
		menu_event => sub {
			if ( $_[0]->IsFullScreen ) {
				$_[0]->ShowFullScreen(0);
			} else {
				$_[0]->ShowFullScreen(
					1,
					Wx::wxFULLSCREEN_NOCAPTION | Wx::wxFULLSCREEN_NOBORDER
				);
			}
			return;
		},
	);

	return $self;
}

sub title {
	my $self = shift;

	return Wx::gettext('&View');
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $config   = $current->config;
	my $document = $current->document;
	my $doc      = $document ? 1 : 0;

	# Simple check state cases from configuration
	$self->{statusbar}->Check( $config->main_statusbar );

	$self->{lines}->Check( $config->editor_linenumbers );
	$self->{folding}->Check( $config->editor_folding );
	$self->{currentline}->Check( $config->editor_currentline );
	$self->{rightmargin}->Check( $config->editor_right_margin_enable );
	$self->{eol}->Check( $config->editor_eol );
	$self->{whitespaces}->Check( $config->editor_whitespace );
	$self->{output}->Check( $config->main_output );
	$self->{outline}->Check( $config->main_outline );
	$self->{directory}->Check( $config->main_directory );
	$self->{functions}->Check( $config->main_functions );
	$self->{lockinterface}->Check( $config->main_lockinterface );
	$self->{indentation_guide}->Check( $config->editor_indentationguides );
	$self->{show_calltips}->Check( $config->editor_calltips );
	$self->{show_syntaxcheck}->Check( $config->main_syntaxcheck );
	$self->{show_errorlist}->Check( $config->main_errorlist );
	$self->{toolbar}->Check( $config->main_toolbar );

	# Check state for word wrap is document-specific
	if ($document) {
		my $editor = $document->editor;
		my $mode   = $editor->GetWrapMode;
		my $wrap   = $self->{word_wrap};
		if ( $mode eq Wx::wxSTC_WRAP_WORD and not $wrap->IsChecked ) {
			$wrap->Check(1);
		} elsif ( $mode eq Wx::wxSTC_WRAP_NONE and $wrap->IsChecked ) {
			$wrap->Check(0);
		}

		# Set mimetype
		my $has_checked = 0;
		if ( $document->get_mimetype ) {
			my %mimes = Padre::Document::menu_view_mimes();
			my @mimes = sort keys %mimes;
			foreach my $pos ( 0 .. scalar @mimes - 1 ) {
				my $radio = $self->{view_as_highlighting}->FindItemByPosition($pos);
				if ( $document->get_mimetype eq $mimes{ $mimes[$pos] } ) {
					$radio->Check(1);
					$has_checked = 1;
				}
			}
		}

		# By default 'Plain Text';
		$self->{view_as_highlighting}->FindItemByPosition(0)->Check(1) unless $has_checked;
	}

	# Disable zooming and bookmarks if there's no current document
	defined( $self->{font_increase} ) and $self->{font_increase}->Enable($doc);
	defined( $self->{font_decrease} ) and $self->{font_decrease}->Enable($doc);
	defined( $self->{font_reset} )    and $self->{font_reset}->Enable($doc);

	# You cannot set a bookmark unless the current document is on disk.
	if ( defined( $self->{bookmark_set} ) ) {
		my $set = ( $doc and defined $document->filename ) ? 1 : 0;
		$self->{bookmark_set}->Enable($set);
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
