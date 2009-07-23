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

our $VERSION = '0.41';
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
	$self->{lockinterface} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Lock User Interface")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{lockinterface},
		sub {
			$_[0]->on_toggle_lockinterface( $_[1] );
		},
	);

	$self->AppendSeparator;

	# Show or hide GUI elements
	$self->{output} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Output")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{output},
		sub {
			$_[0]->show_output( $_[1]->IsChecked );
		},
	);

	$self->{functions} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Functions")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{functions},
		sub {
			if ( $_[1]->IsChecked ) {
				$_[0]->refresh_functions;
				$_[0]->show_functions(1);
			} else {
				$_[0]->show_functions(0);
			}
		},
	);

	# Show or hide GUI elements
	$self->{outline} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Outline")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{outline},
		sub {
			$_[0]->show_outline( $_[1]->IsChecked );
		},
	);

	$self->{directory} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Directory Tree")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{directory},
		sub {
			$_[0]->show_directory( $_[1]->IsChecked );
		},
	);

	$self->{show_syntaxcheck} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Syntax Check")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{show_syntaxcheck},
		sub {
			$_[0]->on_toggle_syntax_check( $_[1] );
		},
	);

	$self->{show_errorlist} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Error List")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{show_errorlist},
		sub {
			$_[0]->on_toggle_errorlist( $_[1] );
		},
	);

	# On Windows disabling the status bar doesn't work, so don't allow it
	unless (Padre::Constant::WXWIN32) {
		$self->{statusbar} = $self->AppendCheckItem(
			-1,
			Wx::gettext("Show StatusBar")
		);
		Wx::Event::EVT_MENU(
			$main,
			$self->{statusbar},
			sub {
				$_[0]->on_toggle_statusbar( $_[1] );
			},
		);
	}

	$self->{toolbar} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Toolbar")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{toolbar},
		sub {
			$_[0]->on_toggle_toolbar( $_[1] );
		}
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
		my $radio = $self->{view_as_highlighting}->AppendRadioItem( -1, $label );
		Wx::Event::EVT_MENU(
			$main, $radio,
			sub {
				my $doc = $_[0]->current->document;
				if ($doc) {
					$doc->set_mimetype( $mimes{$name} );
					$doc->editor->padre_setup;
					$doc->rebless;
					$doc->remove_color;
					if ( $doc->can('colorize') ) {
						$doc->colorize;
					} else {
						$doc->editor->Colourise( 0, $doc->editor->GetLength );
					}
				}
				$_[0]->refresh;
			},
		);
	}

	$self->AppendSeparator;

	# Editor Functionality
	$self->{lines} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Line Numbers")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{lines},
		sub {
			$_[0]->on_toggle_line_numbers( $_[1] );
		},
	);

	$self->{folding} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Code Folding")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{folding},
		sub {
			$_[0]->on_toggle_code_folding( $_[1] );
		},
	);

	$self->{show_calltips} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Call Tips")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{show_calltips},
		sub {
			$_[0]->config->set(
				'editor_calltips',
				$_[1]->IsChecked ? 1 : 0,
			);
			$_[0]->config->write;
		},
	);

	$self->{currentline} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Current Line")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{currentline},
		sub {
			$_[0]->on_toggle_currentline( $_[1] );
		},
	);

	$self->AppendSeparator;

	# Editor Whitespace Layout
	$self->{eol} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Newlines")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{eol},
		sub {
			$_[0]->on_toggle_eol( $_[1] );
		},
	);

	$self->{whitespaces} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Whitespaces")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{whitespaces},
		sub {
			$_[0]->on_toggle_whitespaces( $_[1] );
		},
	);

	$self->{indentation_guide} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Show Indentation Guide")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{indentation_guide},
		sub {
			$_[0]->on_toggle_indentation_guide( $_[1] );
		},
	);

	$self->{word_wrap} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Word-Wrap")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{word_wrap},
		sub {
			$_[0]->on_word_wrap( $_[1]->IsChecked );
		},
	);

	$self->AppendSeparator;

	# Font Size
	$self->{font_increase} = $self->Append(
		-1,
		Wx::gettext("Increase Font Size\tCtrl-+")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{font_increase},
		sub {
			$_[0]->zoom(+1);
		},
	);

	$self->{font_decrease} = $self->Append(
		-1,
		Wx::gettext("Decrease Font Size\tCtrl--")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{font_decrease},
		sub {
			$_[0]->zoom(-1);
		},
	);

	$self->{font_reset} = $self->Append(
		-1,
		Wx::gettext("Reset Font Size\tCtrl-/")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{font_reset},
		sub {
			$_[0]->zoom( -1 * $_[0]->current->editor->GetZoom );
		},
	);

	$self->AppendSeparator;

	# Bookmark Support
	$self->{bookmark_set} = $self->Append(
		-1,
		Wx::gettext("Set Bookmark\tCtrl-B")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{bookmark_set},
		sub {
			require Padre::Wx::Dialog::Bookmarks;
			Padre::Wx::Dialog::Bookmarks->set_bookmark( $_[0] );
		},
	);

	$self->{bookmark_goto} = $self->Append(
		-1,
		Wx::gettext("Goto Bookmark\tCtrl-Shift-B")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{bookmark_goto},
		sub {
			require Padre::Wx::Dialog::Bookmarks;
			Padre::Wx::Dialog::Bookmarks->goto_bookmark( $_[0] );
		},
	);

	$self->AppendSeparator;

	# Editor Look and Feel
	$self->{style} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Style"),
		$self->{style}
	);
	my %styles = (
		default   => Wx::gettext('Padre'),
		night     => Wx::gettext('Night'),
		ultraedit => Wx::gettext('Ultraedit'),
		notepad   => Wx::gettext('Notepad++'),
	);
	my @order = sort { ( $b eq 'default' ) <=> ( $a eq 'default' ) or $styles{$a} cmp $styles{$b} } keys %styles;
	foreach my $name (@order) {
		my $label = $styles{$name};
		my $radio = $self->{style}->AppendRadioItem( -1, $label );
		if ( $config->editor_style and $config->editor_style eq $name ) {
			$radio->Check(1);
		}
		Wx::Event::EVT_MENU(
			$main, $radio,
			sub {
				$_[0]->change_style($name);
			},
		);
	}

	my $dir = File::Spec->catdir( Padre::Constant::CONFIG_DIR, 'styles' );
	my @private =
		map { substr( File::Basename::basename($_), 0, -4 ) } File::Glob::glob( File::Spec->catdir( $dir, '*.yml' ) );
	if (@private) {
		$self->AppendSeparator;
		foreach my $name (@private) {
			my $label = $name;
			my $radio = $self->{style}->AppendRadioItem( -1, $label );
			if ( $config->editor_style and $config->editor_style eq $name ) {
				$radio->Check(1);
			}
			Wx::Event::EVT_MENU(
				$main, $radio,
				sub {
					$_[0]->change_style( $name, 1 );
				},
			);
		}
	}

	# Language Support
	# TODO: God this is horrible, there has to be a better way
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
	$self->{language_default} = $self->{language}->AppendCheckItem(
		-1,
		Wx::gettext("System Default") . " ($default)"
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{language_default},
		sub {
			$_[0]->change_locale;
		},
	);
	if ( defined $config->locale and $config->locale eq $default ) {
		$self->{language_default}->Check(1);
	}

	$self->{language}->AppendSeparator;

	foreach my $name ( sort { $language{$a} cmp $language{$b} } keys %language ) {
		my $label = $language{$name};
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
		my $radio = $self->{language}->AppendRadioItem( -1, $label );
		Wx::Event::EVT_MENU(
			$main, $radio,
			sub {
				$_[0]->change_locale($name);
			},
		);
		if ( $current eq $name ) {
			$radio->Check(1);
		}
	}

	$self->AppendSeparator;

	# Window Effects
	Wx::Event::EVT_MENU(
		$main,
		$self->Append(
			-1,
			Wx::gettext("&Full Screen\tF11")
		),
		sub {
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

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $config   = $current->config;
	my $document = $current->document;
	my $doc      = $document ? 1 : 0;

	# Simple check state cases from configuration
	unless (Padre::Constant::WXWIN32) {
		$self->{statusbar}->Check( $config->main_statusbar );
	}

	$self->{lines}->Check( $config->editor_linenumbers );
	$self->{folding}->Check( $config->editor_folding );
	$self->{currentline}->Check( $config->editor_currentline );
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
	$self->{font_increase}->Enable($doc);
	$self->{font_decrease}->Enable($doc);
	$self->{font_reset}->Enable($doc);

	# You cannot set a bookmark unless the current document is on disk.
	my $set = ( $doc and defined $document->filename ) ? 1 : 0;
	$self->{bookmark_set}->Enable($set);

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
