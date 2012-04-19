#!/usr/bin/perl

# Tests for the Padre::MIME module and the mime types in it

use strict;
use warnings;
use Test::More tests => 4;
use Test::NoWarnings;
use t::lib::Padre;
use Padre::SLOC;





######################################################################
# Basic tasks

my $sloc = Padre::SLOC->new;
isa_ok( $sloc, 'Padre::SLOC' );

# Check Perl 5 line count in the trivial case
my $count = $sloc->count_perl5( \' ' );
is_deeply(
	$count,
	{   'application/x-perl blank'   => 1,
		'application/x-perl comment' => 0,
		'application/x-perl content' => 0,
		'text/x-pod blank'           => 0,
		'text/x-pod comment'         => 0,
	},
	'Got expected Perl 5 line count',
);

# Check Perl 5 line count
$count = $sloc->count_perl5( \<<'END_PERL');
# A comment

=pod

=head1 NAME

This is documentation

=cut

# Another comment
print "Hello World!\n"; # comment
exit(0);

END_PERL
is_deeply(
	$count,
	{   'application/x-perl blank'   => 4,
		'application/x-perl comment' => 2,
		'application/x-perl content' => 2,
		'text/x-pod blank'           => 3,
		'text/x-pod comment'         => 4,
	},
	'Got expected Perl 5 line count',
);
