package Padre::Transform;

=pod

=head1 NAME

Padre::Transform - Padre Document Transform API

=head1 DESCRIPTION

This is the base class for the Padre transform API.

I'll document this more later...

-- Adam K

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Params::Util ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';





#####################################################################
# Constructor

=pod

=head2 new

A default constructor for transform objects.

Takes arbitrary key/value pair parameters and returns a new object.

=cut

sub new {
	my $class = shift;
	bless {@_}, $class;
}





#####################################################################
# Main Methods

=pod

=head2 scalar_delta

  my $delta = $transform->scalar_delta($input_ref);

The C<scalar_delta> method takes a reference to a C<SCALAR> as the only
parameter and changes the document.

If the transform class does not implement a C<scalar_delta> itself the default
implementation will pass the call through to C<scalar_scalar> and then convert
the result to a L<Padre::Delta> object itself.

Returns a new L<Padre::Delta> as output, or throws an exception on error.

=cut

sub scalar_delta {
	my $self   = shift;
	my $input  = shift;
	my $output = $self->scalar_scalar($input);

	# Convert the regular scalar output to a delta
	require Padre::Delta;
	return Padre::Delta->new unless $output;
	return Padre::Delta->from_scalars( $input => $output );
}

=pod

=head2 scalar_scalar

  my $output_ref = $transform->scalar_scalar($input_ref);

The C<scalar_scalar> method takes a reference to a C<SCALAR> as the only
parameter and changes the document.

Returns a new reference to a C<SCALAR> as output, false if there is no change
to the document, or throws an exception on error.

=cut

sub scalar_scalar {
	my $self  = shift;
	my $input = shift;

	# No change to the document by default

	return '';
}

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
