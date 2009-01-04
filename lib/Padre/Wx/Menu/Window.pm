package Padre::Wx::Menu::Window;

# Fully encapsulated Window menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Submenu ();
use Padre::Current     qw{_CURRENT};

our $VERSION = '0.22';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{alt} = [];




	# Split Window
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("&Split window")
		),
		\&Padre::Wx::MainWindow::on_split_window,
	);

	$self->AppendSeparator;





	# File Navigation
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Next File\tCtrl-TAB")
		),
		\&Padre::Wx::MainWindow::on_next_pane,
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Previous File\tCtrl-Shift-TAB")
		),
		\&Padre::Wx::MainWindow::on_prev_pane,
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Last Visited File\tCtrl-6")
		),
		\&Padre::Wx::MainWindow::on_last_visited_pane,
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Right Click\tAlt-/")
		),
		sub {
			my $editor = $_[0]->current->editor;
			if ( $editor ) {
				$editor->on_right_down($_[1]);
			}
		},
	);

	$self->AppendSeparator;





	# Window Navigation
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("GoTo Subs Window\tAlt-S")
		),
		sub {
			$_[0]->{subs_panel_was_closed} = ! Padre->ide->config->{main_subs_panel};
			$_[0]->refresh_methods($_[0]->current);
			$_[0]->show_functions(1); 
			$_[0]->{gui}->{subs_panel}->SetFocus;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("GoTo Output Window\tAlt-O")
		),
		sub {
			$_[0]->show_output(1);
			$_[0]->{gui}->{output_panel}->SetFocus;
		},
	);

	$self->{goto_syntax_check} = $self->Append( -1,
		Wx::gettext("GoTo Syntax Check Window\tAlt-C")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{goto_syntax_check},
		sub {
			$_[0]->show_syntaxbar(1);
			$_[0]->{gui}->{syntaxcheck_panel}->SetFocus;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("GoTo Main Window\tAlt-M")
		),
		sub {
			my $editor = $_[0]->current->editor or return;
			$editor->SetFocus;
		},
	);

	# We'll need to know the number of menu items there are
	# by default so we can add and remove window menu items later.
	$self->{default} = $self->GetMenuItemCount;

	return $self;
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $alt      = $self->{alt};
	my $default  = $self->{default};
	my $items    = $self->GetMenuItemCount;
	my $notebook = $current->_notebook;
	my $pages    = $notebook->GetPageCount;

	# Add or remove menu entries as needed
	if ( $pages ) {
		if ( $items == $default ) {
			$self->{separator} = $self->AppendSeparator;
			$items++;
		}
		my $need = $pages - $items + $default + 1;
		if ( $need > 0 ) {
			foreach ( 1 .. $need ) {
				push @$alt, $self->Append( -1, '' );
			}
		} elsif ( $need < 0 ) {
			foreach ( 1 .. -$need ) {
				$self->Destroy( pop @$alt );
			}
		}
	} else {
		if ( $items > $default ) {
			$self->Destroy( pop @$alt ) while @$alt;
			$self->Destroy( delete $self->{separator} );
		}
	}

	# Update the labels to match the notebooks
	foreach my $i ( 0 .. $#$alt ) {
		my $doc   = $notebook->GetPage($i)->{Document} or return;
		my $label = $doc->filename || $notebook->GetPageText($i);
		$label =~ s/^\s+//;
		$alt->[$i]->SetText($label);
	}

	return 1;
}

1;
