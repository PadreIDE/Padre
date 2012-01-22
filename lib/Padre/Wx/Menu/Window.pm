package Padre::Wx::Menu::Window;

# Fully encapsulated Window menu

use 5.008;
use strict;
use warnings;
use List::Util      ();
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current  ();
use Padre::Feature  ();

our $VERSION = '0.94';
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
	$self->{window_next_file} = $self->add_menu_action(
		'window.next_file',
	);

	$self->{window_previous_file} = $self->add_menu_action(
		'window.previous_file',
	);

	$self->AppendSeparator;
	
	$self->{window_right_click} = $self->add_menu_action(
		'window.right_click',
	);

	$self->AppendSeparator;

	# Window Navigation
	$self->{window_goto_command_window} = $self->add_menu_action(
		'window.goto_command_window',
	);

	$self->{window_goto_cpan_window} = $self->add_menu_action(
		'window.goto_cpan_window',
	) if Padre::Feature::CPAN;

	$self->{window_goto_functions_window} = $self->add_menu_action(
		'window.goto_functions_window',
	);

	$self->{window_goto_outline_window} = $self->add_menu_action(
		'window.goto_outline_window',
	);

	$self->{window_goto_main_window} = $self->add_menu_action(
		'window.goto_main_window',
	);

	$self->{window_goto_syntax_check_window} = $self->add_menu_action(
		'window.goto_syntax_check_window',
	);

	# Save everything we need to keep
	$self->{base} = $self->GetMenuItemCount;

	return $self;
}

sub title {
	Wx::gettext('&Window');
}

sub refresh {
	my $self     = shift;
	my $current  = Padre::Current::_CURRENT(@_);
	my $notebook = $current->notebook or return;
	my $pages    = $notebook->GetPageCount;

	# Toggle window operations based on number of pages
	my $enable = $pages ? 1 : 0;
	$self->{window_next_file}->Enable($enable);
	$self->{window_previous_file}->Enable($enable);
	$self->{window_right_click}->Enable($enable);

	return 1;
}

sub refresh_windowlist {
	my $self     = shift;
	my $current  = Padre::Current::_CURRENT(@_);
	my $notebook = $current->notebook or return;
	my $previous = $self->GetMenuItemCount - $self->{base} - 1;
	my $pages    = $notebook->GetPageCount - 1;
	my @label    = $notebook->labels;
	my @order    = sort { $label[$a][0] cmp $label[$b][0] } ( 0 .. $#label );

	# If we are changing from none to any, add the separator
	if ( $previous == -1 ) {
		$self->AppendSeparator if $pages >= 0;
	} else {
		$previous--;
	}

	# Overwrite the labels of existing entries where possible
	foreach my $nth ( 0 .. List::Util::min( $previous, $pages ) ) {
		my $item = $self->FindItemByPosition( $self->{base} + $nth + 1 );
		$item->SetText( $label[ $order[$nth] ][0] );
		$item->SetHelp( $label[ $order[$nth] ][1] );
	}

	# Add menu entries if we have extra labels
	foreach my $nth ( $previous + 1 .. $pages ) {
		my $item = $self->Append( -1, $label[ $order[$nth] ][0] );
		$item->SetHelp( $label[ $order[$nth] ][1] );
		Wx::Event::EVT_MENU(
			$self->{main},
			$item,
			sub {
				my $id = $notebook->find_pane_by_label( $item->GetLabel );
				return if not defined $id; # TODO warn if this happens!
				$_[0]->on_nth_pane($id);
			},
		);
	}

	# Remove menu entries if we have too many
	foreach my $nth ( reverse( $pages + 1 .. $previous ) ) {
		$self->Delete( $self->FindItemByPosition( $self->{base} + $nth + 1 ) );
	}

	# If we have moved from any to no menus, remove the separator
	if ( $previous >= 0 and $pages == -1 ) {
		$self->Delete( $self->FindItemByPosition( $self->{base} ) );
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
