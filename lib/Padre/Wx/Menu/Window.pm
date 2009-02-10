package Padre::Wx::Menu::Window;

# Fully encapsulated Window menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Menu ();
use Padre::Current     qw{_CURRENT};

our $VERSION = '0.26';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;
	$self->{alt} = [];




	# Split Window
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("&Split window")
		),
		\&Padre::Wx::Main::on_split_window,
	);

	$self->AppendSeparator;





	# File Navigation
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Next File\tCtrl-TAB")
		),
		\&Padre::Wx::Main::on_next_pane,
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Previous File\tCtrl-Shift-TAB")
		),
		\&Padre::Wx::Main::on_prev_pane,
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Last Visited File\tCtrl-6")
		),
		\&Padre::Wx::Main::on_last_visited_pane,
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
			$_[0]->refresh_functions($_[0]->current);
			$_[0]->show_functions(1); 
			$_[0]->functions->SetFocus;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("GoTo Outline Window\tAlt-L")
		),
		sub {
			$_[0]->show_outline(1);
			$_[0]->outline->SetFocus;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("GoTo Output Window\tAlt-O")
		),
		sub {
			$_[0]->show_output(1);
			$_[0]->output->SetFocus;
		},
	);

	$self->{goto_syntax_check} = $self->Append( -1,
		Wx::gettext("GoTo Syntax Check Window\tAlt-C")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{goto_syntax_check},
		sub {
			$_[0]->show_syntax(1);
			$_[0]->syntax->SetFocus;
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
	my $notebook = $current->notebook;
	my $pages    = $notebook->GetPageCount;

	# Add or remove menu entries as needed
	if ( $pages ) {
		if ( $items == $default ) {
			$self->{separator} = $self->AppendSeparator;
			$items++;
		}
		my $need = $pages - $items + $default + 1;
		my $main = $self->{main};
		if ( $need > 0 ) {
			foreach my $i ( 1 .. $need ) {
				my $menu_entry = $self->Append( -1, '' );
				push @$alt, $menu_entry;
				Wx::Event::EVT_MENU( $main, $menu_entry, 
					sub { $main->on_nth_pane($pages - $need + $i -1) } );
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
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
