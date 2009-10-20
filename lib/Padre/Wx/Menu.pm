package Padre::Wx::Menu;

# Implements additional functionality to support richer menus

use 5.008;
use strict;
use warnings;
use Padre::Action ();
use Padre::Wx     ();

use Class::Adapter::Builder
	ISA      => 'Wx::Menu',
	NEW      => 'Wx::Menu',
	AUTOLOAD => 'PUBLIC';

our $VERSION = '0.48';

use Class::XSAccessor getters => {
	wx => 'OBJECT',
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

# Add a normal menu item to menu from a Padre action
sub add_menu_item {
	shift->_add_menu_item( 'Append', @_ );
}

# Add a checked menu item to menu from a Padre action
sub add_checked_menu_item {
	shift->_add_menu_item( 'AppendCheckItem', @_ );
}

# Add a radio menu item to menu from a Padre action
sub add_radio_menu_item {
	shift->_add_menu_item( 'AppendRadioItem', @_ );
}

# Add a normal menu item to menu from a existing Padre action
sub add_menu_action {
	my $self        = shift;
	my $menu        = shift;
	my $action_name = shift;

	my $actions  = Padre->ide->actions;
	if (!defined($actions->{$action_name})) {
		warn 'Action "'.$action_name.'" could not be found!';
		return 0;
	}
	my $action   = $actions->{$action_name};
	my $name     = $action->name;
	my $shortcut = $action->shortcut;
	my $method   = $action->menu_method || 'Append';

	my $item = $menu->$method(
		$action->id,
		$action->label_menu,
	);
	$item->Check( $action->{checked_default} )
		if $method eq 'AppendCheckItem';

	Wx::Event::EVT_MENU(
		$self->{main},
		$item,
		$action->menu_event,
	);

	return $item;
}

# (Private method)
# Add a normal/checked/radio menu item to menu from a Padre action
sub _add_menu_item {
	my $self     = shift;
	my $method   = shift;
	my $menu     = shift;
	my $action   = Padre::Action->new(@_);
	my $name     = $action->name;
	my $shortcut = $action->shortcut;

	my $item = $menu->$method(
		$action->id,
		$action->label_menu,
	);
	Wx::Event::EVT_MENU(
		$self->{main},
		$item,
		$action->menu_event,
	);

	# Adding actions to the main action hash has been moved to
	# Action.pm for compatibility.

	return $item;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
