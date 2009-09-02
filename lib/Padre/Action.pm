package Padre::Action;

use 5.008;
use strict;
use warnings;

use Padre::Constant ();

our $VERSION = '0.45';

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
