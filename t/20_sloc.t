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
my $count = $sloc->count_perl5(\' ');
is_deeply(
	$count,
	{
		'application/x-perl' => 0,
		'text/x-pod'         => 0,
		'comment'            => 0,
		'blank'              => 1,
	},
	'Got expected Perl 5 line count',
);

# Check Perl 5 line count
$count = $sloc->count_perl5(\<<'END_PERL');
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
	{
		'application/x-perl' => 2,
		'text/x-pod'         => 4,
		'comment'            => 2,
		'blank'              => 7,
	},
	'Got expected Perl 5 line count',
);
