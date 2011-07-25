package Padre::DB::Migrate::Patch3;

use strict;
use warnings;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.85';
our @ISA     = 'Padre::DB::Migrate::Patch';





######################################################################
# Migrate Forwards

sub upgrade {
	my $self = shift;

	# Remove the dedundant modules table
	$self->do('DROP TABLE modules');

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

