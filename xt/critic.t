#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Spec::Functions ':ALL';

BEGIN {
	my $config = catfile('xt', 'critic.ini');
	unless ( eval "use Test::Perl::Critic -profile => '$config'; 1" ) {
		plan skip_all => 'Test::Perl::Critic required to criticise code';
	}
}

# need to skip t/files and t/collection
all_critic_ok(
	'blib/lib/Padre',
	glob('t/*.t'),
	't/win32/',
	't/author_tests/',
	't/lib'
);
