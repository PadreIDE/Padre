package Padre::QuickFixProvider;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.43';

#
# Constructor.
# No need to override this
#
sub new {
	my ($class) = @_;

	# Create myself :)
	my $self = bless {}, $class;

	return $self;
}

1;

__END__

=head1 NAME

Padre::QuickFixProvider - Padre Quick Fix Provider API

=head1 DESCRIPTION

The B<Padre::QuickFixProvider> class provides a base class, default implementation
and API documentation for quick fix provision support in L<Padre>.

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
