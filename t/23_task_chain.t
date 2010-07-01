#!/usr/bin/perl

# Start a worker thread from inside another thread

#BEGIN {
#$Padre::TaskThread::DEBUG = 1;
#$Padre::TaskWorker::DEBUG = 1;
#}

use strict;
use warnings;
use Test::More tests => 20;
use Test::NoWarnings;
use Time::HiRes 'sleep';
use Padre::Logger;
use Padre::TaskThread ();
use Padre::TaskWorker ();

# Do we start with no threads as expected
is( scalar( threads->list ), 0, 'One thread exists' );





######################################################################
# Single Worker Start and Stop

SCOPE: {

	# Create the master thread
	my $master = Padre::TaskThread->new->spawn;
	isa_ok( $master, 'Padre::TaskThread' );
	is( scalar( threads->list ), 1, 'Found 1 thread' );
	ok( $master->is_running, 'Master is_running' );

	# Create a single worker
	my $worker = Padre::TaskWorker->new;
	isa_ok( $worker, 'Padre::TaskWorker' );

	# Start the worker inside the master
	ok( $master->start($worker), '->add ok' );
	TRACE("Pausing to allow worker thread startup...") if DEBUG;
	sleep 0.1;
	is( scalar( threads->list ), 2, 'Found 2 threads' );
	ok( $master->is_running,   'Master is_running' );
	ok( !$master->is_joinable, 'Master is not is_joinable' );
	ok( !$master->is_detached, 'Master is not is_detached' );
	ok( $worker->is_running,   'Worker is_running' );
	ok( !$worker->is_joinable, 'Worker is not is_joinable' );
	ok( !$worker->is_detached, 'Worker is not is_detached' );

	# Shut down the worker but leave the master running
	ok( $worker->stop, '->stop ok' );
	TRACE("Pausing to allow worker thread shutdown...") if DEBUG;
	sleep 0.1;
	ok( $master->is_running,   'Master is_running' );
	ok( !$master->is_joinable, 'Master is not is_joinable' );
	ok( !$master->is_detached, 'Master is not is_detached' );
	ok( !$worker->thread,      'Worker thread has ended' );
}

is( scalar( threads->list ), 1, 'Thread is gone' );
