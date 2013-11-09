package Padre::Wx::Role::Context;

=pod

=head1 NAME

Padre::Wx::Role::Context - Role for Wx objects that implement context menus

=head1 DESCRIPTION

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.95';





######################################################################
# Main Methods

=pod

=head2 context_bind

    sub new {
        my $class = shift;
        my $self  = $class->SUPER::new(@_);
    
        $self->context_bind('my_menu');
    
        return $self;
    }
    
    sub my_menu {
        # Fill the menu here
    }

The C<context_bind> method binds an context menu event to default
menu creation and popup logic, and specifies the method that should be
called to fill the context menu with the menu entries.

It takes a single optional parameter of the method to be called to fill
the menu.

If no method is provided then the method C<context_menu> will be bound
to the context menu event by default.

=cut

sub context_bind {
	my $self = shift;
	my $method = shift || 'context_menu';
	unless ( defined $method and $self->can($method) ) {
		die "Missing or invalid content menu method '$method'";
	}
	Wx::Event::EVT_CONTEXT(
		$self,
		sub {
			shift->context_popup($method);
		},
	);
}

=pod

=head2 context_popup

    $self->context_popup('context_menu');

The C<context_popup> menu triggers the immediate display of the popup
menu for the object. It takes a compulsory single parameter, which should
be the method to be used to fill the menu with entries.

=cut

sub context_popup {
	my $self   = shift;
	my $method = shift;

	# Create the empty menu
	my $menu = Wx::Menu->new;

	# Fill the menu
	$self->$method($menu);

	# Show the menu at the current cursor position
	$self->PopupMenu( $menu => Wx::DefaultPosition );
}

=pod

=head2 context_menu

The C<context_menu> method is the default method called to fill a context
menu with menu entries.

It should be overloaded in any class that uses the context menu role.

A minimalist default implementation is provided which will show a single
meny entry to launch the C<About Padre> dialog.

=cut

sub context_menu {
	my $self = shift;
	my $menu = shift;
	$self->context_append_action( $menu => 'help.about' );
}





######################################################################
# Menu Construction Methods

=pod

=head2 context_append_function

    $self->context_append_function(
        $menu,
        Wx::gettext('Do Something'),
        sub {
            # Do something
        },
    );

The C<context_append_function> method adds a menu entry bound to an
arbitrary function call.

The function will be passed the parent object (C<$self> in the above
example) and the event object.

=cut

sub context_append_function {
	my ( $self, $menu, $label, $function ) = @_;
	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, $label ),
		$function,
	);
}

=pod

=head2 context_append_method

    $self->context_append_method
        $menu,
        Wx::gettext('Do Something'),
        'my_method',
    );

The C<context_append_method> method adds a mene entry bound to a named
method on the object.

The method will be passed the event object.

=cut

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

=pod

=head2 context_append_action

    $self->context_append_action(
        $menu,
        'help.about',
    );

The C<context_append_action> method adds a menu entry bound to execute a
named action from L<Padre::Wx::ActionLibrary>.

The menu entry created as a result of this call is functionally identical
to a normal menu entry from the menu bar on the main window.

=cut

sub context_append_action {
	my $self   = shift;
	my $menu   = shift;
	my $name   = shift;
	my $action = $self->ide->actions->{$name} or return 0;

	# Create the menu item object
	my $method = $action->menu_method || 'Append';
	my $item = $menu->$method(
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

=pod

=head2 context_append_options

    $self->context_append_options(
        $menu,
        'main_functions_panel',
    );

The C<context_append_options> method adds a group of several radio menu
entries that allow changing a configuration preference immediately.

The current value of the configuration preference will be checked in the
radio group for information purposes.

=cut

sub context_append_options {
	my $self   = shift;
	my $menu   = shift;
	my $name   = shift;
	my $config = $self->config;
	my $old    = $config->$name();

	# Get the set of (sorted) options
	my $options = $config->meta($name)->options;
	my @list = sort { $a->[1] cmp $b->[1] } map { [ $_, Wx::gettext( $options->{$_} ) ] } keys %$options;

	# Add the menu items
	foreach my $option (@list) {
		my $radio = $menu->AppendRadioItem( -1, $option->[1] );
		my $new = $option->[0];
		if ( $new eq $old ) {
			$radio->Check(1);
		}
		Wx::Event::EVT_MENU(
			$self, $radio,
			sub {
				shift->config->apply( $name => $new );
			},
		);
	}
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
