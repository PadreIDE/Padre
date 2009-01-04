package Padre::Wx::Menu::View;

# Fully encapsulated View menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Submenu ();
use Padre::Current     ();

our $VERSION = '0.22';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = Padre->ide->config;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);





	# Show or hide GUI elements
	$self->{output} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Output")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{output},
		sub {
			$_[0]->show_output( $_[1]->IsChecked );
		},
	);

	$self->{functions} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Functions")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{functions},
		sub {
			if ( $_[1]->IsChecked ) {
				$_[0]->refresh_methods;
				$_[0]->show_functions(1);
			}
			else {
				$_[0]->show_functions(0);
			}
		},
	);

	$self->{show_syntaxcheck} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Syntax Check")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{show_syntaxcheck},
		sub {
			$_[0]->on_toggle_syntax_check($_[1]);
		},
	);

	$self->{show_errorlist} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Error List")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{show_errorlist},
		sub {
			$_[0]->on_toggle_errorlist($_[1]);
		},
	);

	# On Windows disabling the status bar doesn't work, so don't allow it
	unless ( Padre::Util::WIN32 ) {
		$self->{statusbar} = $self->AppendCheckItem( -1,
			Wx::gettext("Show StatusBar")
		);
		Wx::Event::EVT_MENU( $main,
			$self->{statusbar},
			sub {
				$_[0]->on_toggle_status_bar($_[1]);
			},
		);
	}

	$self->AppendSeparator;



	# View as (Highlighting File Type)
	$self->{view_as_highlighting} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("View Document As..."),
		$self->{view_as_highlighting}
	);

	my %mimes = Padre::Document::menu_view_mimes();
	foreach my $name ( sort keys %mimes ) {
		my $label = $name;
		$label =~ s/^\d+//;
		my $radio = $self->{view_as_highlighting}->AppendRadioItem( -1, $label );
		Wx::Event::EVT_MENU( $main,
			$radio,
			sub {
				my $doc = $_[0]->current->document;
				if ( $doc ) {
					$doc->set_mimetype( $mimes{$name} );
					$doc->editor->padre_setup;
					$doc->rebless;
				}
				$_[0]->refresh;
			},
		);
	}

	$self->AppendSeparator;



	# Editor Functionality
	$self->{lines} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Line Numbers")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{lines},
		sub {
			$_[0]->on_toggle_line_numbers($_[1]);
		},
	);

	$self->{folding} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Code Folding")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{folding},
		sub {
			$_[0]->on_toggle_code_folding($_[1]);
		},
	);

	$self->{show_calltips} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Call Tips")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{show_calltips},
		sub {
			Padre->ide->config->{editor_calltips} = $_[1]->IsChecked;
		},
	);

	$self->{current_line_background} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Current Line")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{current_line_background},
		sub {
			$_[0]->on_toggle_current_line_background($_[1]);
		},
	);

	$self->AppendSeparator;





	# Editor Whitespace Layout
	$self->{eol} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Newlines")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{eol},
		sub {
			$_[0]->on_toggle_eol($_[1]);
		},
	);

	$self->{whitespaces} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Whitespaces")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{whitespaces},
		sub {
			$_[0]->on_toggle_whitespaces($_[1]);
		},
	);

	$self->{indentation_guide} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Indentation Guide")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{indentation_guide},
		sub {
			$_[0]->on_toggle_indentation_guide($_[1]);
		},
	);

	$self->{word_wrap} = $self->AppendCheckItem( -1,
		Wx::gettext("Word-Wrap")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{word_wrap},
		sub {
			$_[0]->on_word_wrap( $_[1]->IsChecked );
		},
	);

	$self->AppendSeparator;	





	# Font Size
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Increase Font Size\tCtrl-+")
		),
		sub {
			$_[0]->zoom(+1);
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Decrease Font Size\tCtrl--")
		),
		sub {
			$_[0]->zoom(-1);
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Reset Font Size\tCtrl-/")
		),
		sub {
			$_[0]->zoom( -1 * $_[0]->current->editor->GetZoom );
		},
	);

	$self->AppendSeparator;





	# Bookmark Support
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Set Bookmark\tCtrl-B")
		),
		sub {
			Padre::Wx::Dialog::Bookmarks->set_bookmark($_[0]);
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Goto Bookmark\tCtrl-Shift-B")
		),
		sub {
			Padre::Wx::Dialog::Bookmarks->goto_bookmark($_[0]);
		},
	);

	$self->AppendSeparator;





	# Styles (temporary location?)
	$self->{style} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Style"),
		$self->{style}
	);
	
	# TODO: name should be localized
	my %styles = ( default => 'Default', night => 'Night' );
	
	foreach my $name ( sort { $styles{$a} cmp $styles{$b} }  keys %styles) {
		my $label = $styles{$name};
		my $radio = $self->{style}->AppendRadioItem( -1, $label );
		if ( $config->{host}->{style} and $config->{host}->{style} eq $name ) {
			$radio->Check(1);
		}
		Wx::Event::EVT_MENU( $main,
			$radio,
			sub {
				$_[0]->change_style($name);
			},
		);
	}

	my $dir = File::Spec->catdir( Padre::Config->default_dir , 'styles' );
	my @private_styles =
		map { substr File::Basename::basename($_), 0, -4 }
		glob File::Spec->catdir( $dir, '*.yml' );
	if (@private_styles) {
		$self->AppendSeparator;
		foreach my $name (@private_styles) {
			my $label = $name;
			my $radio = $self->{style}->AppendRadioItem( -1, $label );
			if ( $config->{host}->{style} and $config->{host}->{style} eq $name ) {
				$radio->Check(1);
			}
			Wx::Event::EVT_MENU( $main,
				$radio,
				sub {
					$_[0]->change_style($name, 1);
				},
			);
		}
	}





	# Language Support
	$self->{language} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Language"),
		$self->{language}
	);
	Wx::Event::EVT_MENU( $main,
		$self->{language}->AppendRadioItem( -1, Wx::gettext("System Default") ),
		sub {
			$_[0]->change_locale;
		},
	);

	$self->{language}->AppendSeparator;

	my %languages = Padre::Locale::menu_view_languages();
	foreach my $name ( sort { $languages{$a} cmp $languages{$b} }  keys %languages) {
		my $label = $languages{$name};
		if ( $label eq 'English' ) {
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
		Wx::Event::EVT_MENU( $main,
			$radio,
			sub {
				$_[0]->change_locale($name);
			},
		);
		if ( $config->{host}->{locale} and $config->{host}->{locale} eq $name ) {
			$radio->Check(1);
		}
	}

	$self->AppendSeparator;





	# Window Effects
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("&Full Screen\tF11")
		),
		sub {
			$_[0]->on_full_screen($_[1]);
		},
	);

	return $self;
}

sub refresh {
	my $self     = shift;
	my $config   = Padre->ide->config;

	# Simple check state cases from configuration
	$self->{lines}->Check( $config->{editor_linenumbers} ? 1 : 0 );
	$self->{folding}->Check( $config->{editor_codefolding} ? 1 : 0 );
	$self->{current_line_background}->Check( $config->{editor_current_line_background} ? 1 : 0 );
	$self->{eol}->Check( $config->{editor_eol} ? 1 : 0 );
	$self->{whitespaces}->Check( $config->{editor_whitespaces} ? 1 : 0 );
	unless ( Padre::Util::WIN32 ) {
		$self->{statusbar}->Check( $config->{main_statusbar} ? 1 : 0 );
	}
	$self->{output}->Check( $config->{main_output_panel} ? 1 : 0 );
	$self->{functions}->Check( $config->{main_subs_panel} ? 1 : 0 );
	$self->{indentation_guide}->Check( $config->{editor_indentationguides} ? 1 : 0 );
	$self->{show_calltips}->Check( $config->{editor_calltips} ? 1 : 0 );
	$self->{show_syntaxcheck}->Check( $config->{editor_syntaxcheck} ? 1 : 0 );
	$self->{show_errorlist}->Check( $config->{editor_errorlist} ? 1 : 0 );

	# Check state for word wrap is document-specific
	my $document = Padre::Current->document;
	if ( $document ) {
		my $editor = $document->editor;
		my $mode   = $editor->GetWrapMode;
		my $wrap   = $self->{word_wrap};
		if ( $mode eq Wx::wxSTC_WRAP_WORD and not $wrap->IsChecked ) {
			$wrap->Check(1);
		} elsif ( $mode eq Wx::wxSTC_WRAP_NONE and $wrap->IsChecked ) {
			$wrap->Check(0);
		}
		
		# set mimetype
		my $has_checked = 0;
		if ( $document->get_mimetype ) {
    		my %mimes = Padre::Document::menu_view_mimes();
    		my @mimes = sort keys %mimes;
    		foreach my $pos ( 0 .. scalar @mimes - 1 ) {
    			my $radio = $self->{view_as_highlighting}->FindItemByPosition($pos);
    			if ( $document->get_mimetype eq $mimes{$mimes[$pos]} ) {
    				$radio->Check(1);
    				$has_checked = 1;
    			}
    		}
    	}
    	# by default, 'Plain Text';
    	$self->{view_as_highlighting}->FindItemByPosition(0)->Check(1) unless $has_checked;
	}

	return;
}

1;
