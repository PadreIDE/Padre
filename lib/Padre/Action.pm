package Padre::Action;

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

=cut

use 5.008;
use strict;
use warnings;

our $VERSION = '0.43';

# Generate faster accessors
use Class::XSAccessor accessors => {
	name          => 'name',
	id            => 'id',
	label         => 'label',
	icon          => 'icon',
	shortcut      => 'shortcut',
	menu_event    => 'menu_event',
	toolbar_event => 'toolbar_event',
};

#####################################################################
# Constructor

=pod

=head2 new

A default contructor for action objects.

=cut

sub new {
	my ( $class, %opts ) = @_;

	#XXX - validate options

	my $self = bless {}, $class;

	$self->name( $opts{name} );
	$self->id( $opts{id} || -1 );
	$self->label( $opts{label} );
	$self->icon( $opts{icon} );
	$self->shortcut( $opts{shortcut} );
	$self->menu_event( $opts{menu_event} );
	$self->toolbar_event( $opts{toolbar_event} );

	return $self;
}

#
# A label textual data without any strange menu characters
#
sub label_text {
	my $self  = shift;
	my $label = $self->label;
	$label =~ s/\&//g;
	return $label;
}

#####################################################################
# Main Methods

=pod

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
