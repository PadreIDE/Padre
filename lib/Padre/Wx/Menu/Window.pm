package Padre::Wx::Menu::Window;

# Fully encapsulated Window menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current  ('_CURRENT');

our $VERSION = '0.57';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);
	$self->{main} = $main;

	# File Navigation
	$self->{window_last_visited_file} = $self->add_menu_action(
		$self,
		'window.last_visited_file',
	);

	$self->{window_oldest_visited_file} = $self->add_menu_action(
		$self,
		'window.oldest_visited_file',
	);

	$self->{window_next_file} = $self->add_menu_action(
		$self,
		'window.next_file',
	);

	$self->{window_previous_file} = $self->add_menu_action(
		$self,
		'window.previous_file',
	);

	# TODO: Remove this and the menu option as soon as #750 is fixed
	#       as it's the same like Ctrl-Tab
	$self->add_menu_action(
		$self,
		'window.last_visited_file_old',
	);

	$self->{window_right_click} = $self->add_menu_action(
		$self,
		'window.right_click',
	);

	$self->AppendSeparator;

	# Window Navigation
	$self->{window_goto_functions_window} = $self->add_menu_action(
		$self,
		'window.goto_functions_window',
	);

	$self->{window_goto_outline_window} = $self->add_menu_action(
		$self,
		'window.goto_outline_window',
	);

	$self->{window_goto_syntax_check_window} = $self->add_menu_action(
		$self,
		'window.goto_syntax_check_window',
	);

	$self->{window_goto_main_window} = $self->add_menu_action(
		$self,
		'window.goto_main_window',
	);

	# Add additional properties
	$self->{base} = $self->GetMenuItemCount;

	return $self;
}

sub title {
	Wx::gettext('&Window');
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $notebook = $current->notebook;
	my $menus    = $self->{menus};

	# Destroy previous window list so we can add it again.
	# The list must be deleted backwards from the bottom to the top.
	my @delete = ( $self->{base} + 1 .. $self->GetMenuItemCount - 1 );
	foreach my $i ( reverse @delete ) {
		$self->Delete( $self->FindItemByPosition($i) );
	}

	# Add or remove the separator
	my $pages = $notebook->GetPageCount;
	if ( $self->{separator} and not $pages ) {
		$self->Delete( delete $self->{separator} );
	} elsif ( $pages and not $self->{separator} ) {
		$self->{separator} = $self->AppendSeparator;
	}

	# Add all of the window entries
	$DB::single = 1;
	my @label = $notebook->labels;
	foreach my $nth ( sort { $label[$a] cmp $label[$b] } ( 0 .. $#label ) ) {
		push @$menus, $self->Append( -1, $label[$nth] );
		Wx::Event::EVT_MENU(
			$self->{main},
			$menus->[-1],
			sub {
				$_[0]->on_nth_pane($nth);
			},
		);
	}

	# Toggle window operations based on number of pages
	my $enable = $pages ? 1 : 0;
	$self->{window_next_file}->Enable($enable);
	$self->{window_previous_file}->Enable($enable);
	$self->{window_last_visited_file}->Enable($enable);
	$self->{window_right_click}->Enable($enable);

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
