#!/usr/bin/perl

# Start a worker thread from inside another thread

# BEGIN {
# $Padre::Logger::DEBUG = 1;
# $Padre::TaskWorker::DEBUG = 1;
# $Padre::TaskWorker::DEBUG = 1;
# }

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
}
use Time::HiRes 'sleep';
use Padre::Logger;
use Padre::TaskWorker ();
use Padre::TaskWorker ();


plan tests => 21;
use_ok('Test::NoWarnings');

# Do we start with no threads as expected
is( scalar( threads->list ), 0, 'One thread exists' );





######################################################################
# Single Worker Start and Stop

SCOPE: {

	# Create the master thread
	my $master = Padre::TaskWorker->new->spawn;
	isa_ok( $master, 'Padre::TaskWorker' );
	is( scalar( threads->list ), 1, 'Found 1 thread' );
	ok( $master->thread->is_running, 'Master is_running' );

	# Create a single worker
	my $worker = Padre::TaskWorker->new;
	isa_ok( $worker, 'Padre::TaskWorker' );

	# Start the worker inside the master
	ok( $master->send_child($worker), '->add ok' );
	TRACE("Pausing to allow worker thread startup...") if DEBUG;
	sleep 0.15; #0.1 was not enough
	is( scalar( threads->list ), 2, 'Found 2 threads' );
	ok( $master->thread->is_running,   'Master is_running' );
	ok( !$master->thread->is_joinable, 'Master is not is_joinable' );
	ok( !$master->thread->is_detached, 'Master is not is_detached' );
	ok( $worker->thread->is_running,   'Worker is_running' );
	ok( !$worker->thread->is_joinable, 'Worker is not is_joinable' );
	ok( !$worker->thread->is_detached, 'Worker is not is_detached' );

	# Shut down the worker but leave the master running
	ok( $worker->send_stop, '->send_stop ok' );
	TRACE("Pausing to allow worker thread shutdown...") if DEBUG;
	sleep 0.1;
	ok( $master->thread->is_running,   'Master is_running' );
	ok( !$master->thread->is_joinable, 'Master is not is_joinable' );
	ok( !$master->thread->is_detached, 'Master is not is_detached' );

	# Join the thread
	$worker->thread->join;
	ok( !$worker->thread, 'Worker thread has ended' );
}

is( scalar( threads->list ), 1, 'Thread is gone' );
