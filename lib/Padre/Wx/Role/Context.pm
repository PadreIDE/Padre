package Padre::Wx::Role::Context;

# Role for creating context menus for objects

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION    = '0.95';
our $COMPATIBLE = '0.95';





######################################################################
# Main Methods

sub context_bind {
	my $self   = shift;
	my $method = shift || 'context_menu';
	unless ( defined $method and $self->can($method) ) {
		die "Missing or invalid content menu method '$method'";
	}
	Wx::Event::EVT_CONTEXT(
		$self,
		sub {
			$_[0]->context_popup( $_[1], $method );
		},
	);
}

sub context_popup {
	my $self   = shift;
	my $event  = shift;
	my $method = shift;

	# Create the empty menu
	my $menu = Wx::Menu->new;

	# Fill the menu
	$self->$method($menu);

	# Show the menu at the current cursor position
	$self->PopupMenu( $menu => Wx::DefaultPosition );
}

# Default implementation of the method to allow it to be legal
sub context_menu {
	my $self = shift;
	my $menu = shift;

	# Always do something...
	$self->context_append_action( $menu => 'help.about' );

	return;
}





######################################################################
# Menu Construction Methods

sub context_append_function {
	my ( $self, $menu, $label, $function ) = @_;
	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, $label ),
		$function,
	);
}

sub context_append_method {
	my ( $self, $menu, $label, $method ) = @_;
	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, $label ),
		sub {
			shift->$method(@_);
		},
	);
}

sub context_append_action {
	my $self   = shift;
	my $menu   = shift;
	my $name   = shift;
	my $action = $self->ide->actions->{$name} or return 0;

	# Create the menu item object
	my $method = $action->menu_method || 'Append';
	my $item   = $menu->$method(
		$action->id,
		$action->label_menu,
	);

	# Assign help if applicable
	my $comment = $action->comment;
	$item->SetHelp($comment) if $comment;

	# Unlike the regular stuff, bind actions to the main window
	Wx::Event::EVT_MENU(
		$self->main,
		$item,
		$action->menu_event,
	);
}

sub context_append_options {
	my $self   = shift;
	my $menu   = shift;
	my $name   = shift;
	my $config = $self->config;
	my $old    = $config->$name();

	# Get the set of (sorted) options
	my $options = $config->meta($name)->options;
	my @list    = sort {
		$a->[1] cmp $b->[1]
	} map {
		[ $_, Wx::gettext($options->{$_}) ]
	} keys %$options;

	# Add the menu items
	foreach my $option ( @list ) {
		my $radio = $menu->AppendRadioItem( -1, $option->[1] );
		my $new   = $option->[0];
		if ( $new eq $old ) {
			$radio->Check(1);
		}
		Wx::Event::EVT_MENU(
			$self,
			$radio,
			sub {
				shift->config->apply( $name => $new );
			},
		);
	}
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
