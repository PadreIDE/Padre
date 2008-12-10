package Padre::Wx::Menu::View;

# Fully encapsulated View menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Submenu ();
use Padre::Documents   ();

our $VERSION = '0.20';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);





	# Show or hide GUI elements
	$self->{view_output} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Output")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_output},
		sub {
			$_[0]->show_output( $_[1]->IsChecked );
		},
	);

	$self->{view_functions} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Functions")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_functions},
		sub {
			$_[0]->show_functions( $_[1]->IsChecked );
		},
	);

	# On Windows disabling the status bar is broken, so don't allow it
	$self->{view_statusbar} = $self->AppendCheckItem( -1,
		Wx::gettext("Show StatusBar")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_statusbar},
		sub {
			$_[0]->on_toggle_status_bar($_[1]);
		},
	) unless Padre::Util::WIN32;

	$self->AppendSeparator;





	# Editor Functionality
	$self->{view_lines} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Line Numbers")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_lines},
		sub {
			$_[0]->on_toggle_line_numbers($_[1]);
		},
	);

	$self->{view_folding} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Code Folding")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_folding},
		sub {
			$_[0]->on_toggle_code_folding($_[1]);
		},
	);

	$self->{view_show_calltips} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Call Tips")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_show_calltips},
		sub {
			Padre->ide->config->{editor_calltips} = $_[1]->IsChecked;
		},
	);

	$self->{view_currentlinebackground} = $self->AppendCheckItem( -1,
		Wx::gettext("Highlight Current Line")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_currentlinebackground},
		sub {
			$_[0]->on_toggle_current_line_background($_[1]);
		},
	);

	$self->AppendSeparator;





	# Editor Whitespace Layout
	$self->{view_eol} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Newlines")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_eol},
		sub {
			$_[0]->on_toggle_eol($_[1]);
		},
	);

	$self->{view_whitespaces} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Whitespaces")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_whitespaces},
		sub {
			$_[0]->on_toggle_whitespaces($_[1]);
		},
	);

	$self->{view_indentation_guide} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Indentation Guide")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_indentation_guide},
		sub {
			$_[0]->on_toggle_indentation_guide($_[1]);
		},
	);

	$self->{view_word_wrap} = $self->AppendCheckItem( -1,
		Wx::gettext("Word-Wrap")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_word_wrap},
		sub {
			$_[0]->on_word_wrap( $_[1]->IsChecked );
		},
	);

	$self->AppendSeparator;	





	# Miscellaneous Editor Functions
	$self->{view_show_syntaxcheck} = $self->AppendCheckItem( -1,
		Wx::gettext("Show Syntax Check")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_show_syntaxcheck},
		sub {
			$_[0]->on_toggle_syntax_check($_[1]);
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
			$_[0]->zoom( -1 * $_[0]->selected_editor->GetZoom );
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





	# Language Support
	$self->{view_language} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Language"),
		$self->{view_language}
	);
	Wx::Event::EVT_MENU( $main,
		$self->{view_language}->AppendRadioItem( -1, Wx::gettext("System Default") ),
		sub {
			$_[0]->change_locale;
		},
	);

	$self->{view_language}->AppendSeparator;

	my $config    = Padre->ide->config;
	my %languages = Padre::Locale::languages();
	foreach my $name ( sort { $languages{$a} cmp $languages{$b} }  keys %languages) {
		my $label = $languages{$name};
		if ( $label eq 'English' ) {
			$label = "English (The Queen's)";
		}

		my $radio = $self->{view_language}->AppendRadioItem( -1, $label );
		if ( $config->{host}->{locale} and $config->{host}->{locale} eq $name ) {
			$radio->Check(1);
		}
		Wx::Event::EVT_MENU( $main,
			$radio,
			sub {
				$_[0]->change_locale($name);
			},
		);
	}

	$self->AppendSeparator;





	# Window Effects
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("&Full screen\tF11")
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
	$self->{view_lines}->Check( $config->{editor_linenumbers} ? 1 : 0 );
	$self->{view_folding}->Check( $config->{editor_codefolding} ? 1 : 0 );
	$self->{view_currentlinebackground}->Check( $config->{editor_currentlinebackground} ? 1 : 0 );
	$self->{view_eol}->Check( $config->{editor_eol} ? 1 : 0 );
	$self->{view_whitespaces}->Check( $config->{editor_whitespaces} ? 1 : 0 );
	unless ( Padre::Util::WIN32 ) {
		$self->{view_statusbar}->Check( $config->{main_statusbar} ? 1 : 0 );
	}
	$self->{view_output}->Check( $config->{main_output_panel} ? 1 : 0 );
	$self->{view_functions}->Check( $config->{main_subs_panel} ? 1 : 0 );
	$self->{view_indentation_guide}->Check( $config->{editor_indentationguides} ? 1 : 0 );
	$self->{view_show_calltips}->Check( $config->{editor_calltips} ? 1 : 0 );
	$self->{view_show_syntaxcheck}->Check( $config->{editor_syntaxcheck} ? 1 : 0 );

	# Check state for word wrap is document-specific
	my $document = Padre::Documents->current;
	if ( $document ) {
		my $editor = $document->editor;
		my $mode   = $editor->GetWrapMode;
		my $wrap   = $self->{view_word_wrap};
		if ( $mode eq Wx::wxSTC_WRAP_WORD and not $wrap->IsChecked ) {
			$wrap->Check(1);
		} elsif ( $mode eq Wx::wxSTC_WRAP_NONE and $wrap->IsChecked ) {
			$wrap->Check(0);
		}
	}

	return;
}

1;
