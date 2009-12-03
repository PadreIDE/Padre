#!/usr/bin/perl

# Enforce higher standards against code that will be installed

use strict;
use warnings;
use Test::More;
use File::Spec::Functions ':ALL';

BEGIN {
	my $config = catfile('xt', 'critic-installed.ini');
	unless ( eval "use Test::Perl::Critic -profile => '$config'; 1" ) {
		plan skip_all => 'Test::Perl::Critic required to criticise code';
	}
}

# need to skip t/files and t/collection
all_critic_ok( 'blib' );
