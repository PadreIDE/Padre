package Padre::Action;

use 5.008;
use strict;
use warnings;

use Padre::Constant ();

our $VERSION = '0.47';

# Generate faster accessors
use Class::XSAccessor getters => {
	id            => 'id',
	icon          => 'icon',
	name          => 'name',
	label         => 'label',
	shortcut      => 'shortcut',
	menu_event    => 'menu_event',
	toolbar_event => 'toolbar_event',
};



#####################################################################
# Constructor

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	$self->{id} ||= -1;

	if ( defined( $self->{menu_event} ) ) {

		# Menu events are handled by Padre::Action, the real events
		# should go to {event}!
		$self->add_event( $self->{menu_event} );
		$self->{menu_event} =
			eval ' return sub {' . "Padre->ide->actions->{'" . $self->{name} . "'}->_event(\@_);" . '};';
	}

	return $self;
}

# A label textual data without any strange menu characters
sub label_text {
	my $self  = shift;
	my $label = $self->label;
	$label =~ s/\&//g;
	return $label;
}

# Label for use with menu (with shortcut)
# In some cases ( http://padre.perlide.org/trac/ticket/485 )
# if a stock menu item also gets a short-cut it stops working
# hence we add the shortcut only if id == -1 indicating this was not a
# stock menu item
# The case of F12 is a special case as it uses a stock icon that does not have
# a shortcut in itself so we added one.
# (BTW Print does not have a shortcut either)
sub label_menu {
	my $self  = shift;
	my $label = $self->label;
	if ( $self->shortcut and ( ( $self->shortcut eq 'F12' ) or ( $self->id == -1 or Padre::Constant::WIN32() ) ) ) {
		$label .= "\t" . $self->shortcut;
	}
	return $label;
}

# Add an event to an action:
sub add_event {
	my $self      = shift;
	my $new_event = shift;

	if ( ref($new_event) ne 'CODE' ) {
		warn 'Error: ' . join( ',', caller ) . ' tried to add "' . $new_event . '" which is no CODE-ref!';
		return 0;
	}

	if ( ref( $self->{event} ) eq 'ARRAY' ) {
		push @{ $self->{event} }, $new_event;
	} elsif ( !defined( $self->{event} ) ) {
		$self->{event} = $new_event;
	} else {
		$self->{event} = [ $self->{event}, $new_event ];
	}

	return 1;
}

sub _event {
	my $self = shift;
	my @args = @_;

	return 1 unless defined( $self->{event} );

	if ( ref( $self->{event} ) eq 'CODE' ) {
		&{ $self->{event} }(@args);
	} elsif ( ref( $self->{event} ) eq 'ARRAY' ) {
		for ( @{ $self->{event} } ) {
			next if ref($_) ne 'CODE'; # TODO: Catch error and source
			&{$_}(@args);
		}
	} else {
		warn 'Expected array or code reference but got: ' . $self->{event};
	}

	return 1;
}

#####################################################################
# Main Methods

=pod

=head1 NAME

Padre::Action - Padre Action Object

=head1 SYNOPSIS

  my $action = Padre::Action->new( 
    name       => 'file.save', 
    label      => 'Save', 
    icon       => '...', 
    shortcut   => 'CTRL-S', 
    menu_event => sub { },
  );

=head1 DESCRIPTION

This is the base class for the Padre Action API.

To be documented...

-- Ahmad M. Zawawi

=head1 METHODS

=head2 new

A default contructor for action objects.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
