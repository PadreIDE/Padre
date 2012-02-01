#!/usr/bin/perl

# Start a worker thread from inside another thread

#BEGIN {
#$Padre::TaskWorker::DEBUG = 1;
#$Padre::TaskWorker::DEBUG = 1;
#}

use strict;
use warnings;
use Test::More;
use Time::HiRes 'sleep';
use Padre::Logger;

######################################################################
# This test requires a DISPLAY to run
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}
plan tests => 8;

use_ok('Test::NoWarnings');
use_ok('Padre::TaskWorker');
is( scalar( threads->list ), 0, 'No threads exists' );

# Fetch the master, is it the existing one?
my $master1 = Padre::TaskWorker->master;
my $master2 = Padre::TaskWorker->master;
isa_ok( $master1, 'Padre::TaskWorker' );
isa_ok( $master2, 'Padre::TaskWorker' );
is( $master1->wid, $master2->wid, 'Masters match' );

sleep 0.1;
is( scalar( threads->list ), 1, 'One thread exists' );
