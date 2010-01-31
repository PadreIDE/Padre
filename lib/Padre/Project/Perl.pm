package Padre::Project::Perl;

# This is not usable yet

use 5.008;
use strict;
use warnings;
use Padre::Project ();

our $VERSION = '0.55';
our @ISA     = 'Padre::Project';





######################################################################
# Directory Integration

sub ignore_rule {
	return sub {

		# Default filter as per normal
		return 0 if $_->{name} =~ /^\./;

		# In a distribution, we can ignore more things
		return 0 if $_->{name} =~ /^(?:blib|_build|inc|Makefile|pm_to_blib)\z/;

		# Everything left, so we show it
		return 1;
	};
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
