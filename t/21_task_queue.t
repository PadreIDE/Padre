#!/usr/bin/perl

# Basic tests for Padre::TaskQueue

use strict;
use warnings;
use Test::More;

######################################################################
# This test requires a DISPLAY to run
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 12;
}
use Test::NoWarnings;
use t::lib::Padre;
use Padre::TaskQueue ();
use Padre::Logger;

# Check the null case
my $queue = Padre::TaskQueue->new;
isa_ok( $queue, 'Padre::TaskQueue' );
is( $queue->pending, 0, '->pending is false' );
SCOPE: {
	my @nb = $queue->dequeue_nb;
	is_deeply( \@nb, [], '->dequeue_nb returns immediately with nothing' );
}

# Add a record and remove non-blocking
$queue->enqueue( [ 'foo', 'bar' ] );
is( $queue->pending, 1, '->pending is true' );
SCOPE: {
	my @nb = $queue->dequeue_nb;
	is_deeply( \@nb, [ [ 'foo', 'bar' ] ], '->dequeue_nb returns the record' );
}

# Add a record and remove blocking
$queue->enqueue( [ 'foo', 'bar' ] );
is( $queue->pending, 1, '->pending is true' );
SCOPE: {
	my @nb = $queue->dequeue;
	is_deeply( \@nb, [ [ 'foo', 'bar' ] ], '->dequeue returns the record' );
}

# Add a record and remove non-blocking
$queue->enqueue( [ 'foo', 'bar' ] );
is( $queue->pending, 1, '->pending is true' );
SCOPE: {
	my $nb = $queue->dequeue1_nb;
	is_deeply( $nb, [ 'foo', 'bar' ], '->dequeue1_nb returns the record' );
}

# Add a record and remove blocking
$queue->enqueue( [ 'foo', 'bar' ] );
is( $queue->pending, 1, '->pending is true' );
SCOPE: {
	my $nb = $queue->dequeue1;
	is_deeply( $nb, [ 'foo', 'bar' ], '->dequeue1 returns the record' );
}
