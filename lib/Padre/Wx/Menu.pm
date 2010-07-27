package Padre::Wx::Menu;

# Implements additional functionality to support richer menus

use 5.008;
use strict;
use warnings;
use Padre::Wx::Action ();
use Padre::Wx         ();

use Class::Adapter::Builder
	ISA      => 'Wx::Menu',
	NEW      => 'Wx::Menu',
	AUTOLOAD => 'PUBLIC';

our $VERSION = '0.67';

use Class::XSAccessor {
	getters => {
		wx => 'OBJECT',
	}
};

# Default implementation of refresh
sub refresh {1}

# Overrides and then calls XS wx Menu::Append.
# Adds any hotkeys to global registry of bound keys
sub Append {
	my $self   = shift;
	my $string = $_[1];
	my $item   = $self->wx->Append(@_);
	my ($underlined) = ( $string =~ m/(\&\w)/ );
	my ($accel)      = ( $string =~ m/(Ctrl-.+|Alt-.+)/ );
	if ( $underlined or $accel ) {
		$self->{main}->{accel_keys} ||= {};
		if ($underlined) {
			$underlined =~ s/&(\w)/$1/;
			$self->{main}->{accel_keys}->{underlined}->{$underlined} = $item;
		}
		if ($accel) {
			my ( $mod, $mod2, $key ) = ( $accel =~ m/(Ctrl|Alt)(-Shift)?\-(.)/ );
			$mod .= $mod2 if ($mod2);
			$self->{main}->{accel_keys}->{hotkeys}->{ uc($mod) }->{ ord( uc($key) ) } = $item;
		}
	}
	return $item;
}

# Add a normal menu item to menu from a existing Padre action
sub add_menu_action {
	my $self    = shift;
	my $menu    = shift;
	my $name    = shift;
	my $actions = Padre->ide->actions;
	my $action  = $actions->{$name} or return 0;
	my $method  = $action->menu_method || 'Append';

	my $item = $menu->$method(
		$action->id,
		$action->label_menu,
	);

	my $comment = $action->comment;
	if ($comment) {
		$item->SetHelp($comment);
	}

	Wx::Event::EVT_MENU(
		$self->{main},
		$item,
		$action->menu_event,
	);

	return $item;
}

sub build_menu_from_actions {
	my $self    = shift;
	my $main    = shift;
	my $actions = shift;

	my $label = $actions->[0];
	$self->{main} = $main;
	$self->_menu_actions_submenu( $main, $self->wx, $actions->[1] );
	return ( $label, $self->wx );
}

# Very Experimental !!!
sub _menu_actions_submenu {
	my $self  = shift;
	my $main  = shift;
	my $menu  = shift;
	my $items = shift;
	unless ( $items and ref $items and ref $items eq 'ARRAY' ) {
		Carp::cluck("Invalid list of actions in plugin");
		return;
	}

	# Fill the menu
	while (@$items) {
		my $value = shift @$items;

		# Separator
		if ( $value eq '---' ) {
			$menu->AppendSeparator;
			next;
		}

		# Array Reference (submenu)
		if ( Params::Util::_ARRAY0($value) ) {
			my $label = shift @$value;
			if ( not defined $label ) {
				Carp::cluck("No label in action sublist");
				next;
			}

			my $submenu = Wx::Menu->new;
			$menu->Append( -1, $label, $submenu );
			$self->_menu_actions_submenu( $main, $submenu, $value );
			next;
		}

		# Action name
		$self->{"menu_$value"} = $self->add_menu_action(
			$menu,
			$value,
		);
	}

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
