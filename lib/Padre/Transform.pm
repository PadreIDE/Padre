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

our $VERSION = '0.90';

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

=head2 apply

  $transform->apply( $padre_document );

The C<apply> method takes a L<Padre::Document> object and modifies it
in place. Returns true if the document was changed, false if not,
or throws an exception on error.

=cut

sub apply {
	my $self = shift;
	my $document = Params::Util::_INSTANCE( shift, 'Padre::Document' );
	unless ($document) {
		die 'Did not provide a Padre::Document object to apply';
	}

	# Null transform

	return '';
}

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
