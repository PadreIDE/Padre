package Padre::QuickFixProvider::Perl;

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

Padre::QuickFixProvider::Perl - Padre Perl 5 Quick Fix Provider

=head1 DESCRIPTION

Perl 5 quick fix are implemented here

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
