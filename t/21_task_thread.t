#!/usr/bin/perl

# Spawn and then shut down the task worker object.
# Done in similar style to the task master to help encourage
# implementation similarity in the future.

use strict;
use warnings;
use Test::More;
use Padre::TaskThread ();
use Padre::Logger;

######################################################################
# This test requires a DISPLAY to run
BEGIN {
        unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
                plan skip_all => 'Needs DISPLAY';
                done_testing;
                exit 0;
        }
}
plan tests => 20;
use_ok('Test::NoWarnings');

# Do we start with no threads as expected
is( scalar( threads->list ), 0, 'One thread exists' );





######################################################################
# Simplistic Start and Stop

SCOPE: {

	# Create the master thread
	my $thread = Padre::TaskThread->new->spawn;
	isa_ok( $thread, 'Padre::TaskThread' );
	is( $thread->wid, 1, '->wid ok' );
	isa_ok( $thread->queue,  'Thread::Queue' );
	isa_ok( $thread->thread, 'threads' );
	ok( !$thread->is_thread, '->is_thread is false' );
	my $tid = $thread->thread->tid;
	ok( $tid, "Got thread id $tid" );

	# Does the threads module agree it was created
	my @threads = threads->list;
	is( scalar(@threads), 1,    'Found one thread' );
	is( $threads[0]->tid, $tid, 'Found the expected thread id' );

	# Initially, the thread should be running
	ok( $thread->is_running,   'Thread is_running' );
	ok( !$thread->is_joinable, 'Thread is not is_joinable' );
	ok( !$thread->is_detached, 'Thread is not is_detached' );

	# It should stay running
	TRACE("Pausing to allow clean thread startup...") if DEBUG;
	sleep 0.1;
	ok( $thread->is_running,   'Thread is_running' );
	ok( !$thread->is_joinable, 'Thread is not is_joinable' );
	ok( !$thread->is_detached, 'Thread is not is_detached' );

	# Instruct the master to shutdown, and give it a brief time to do so.
	ok( $thread->stop, '->stop ok' );
	TRACE("Pausing to allow clean thread shutdown...") if DEBUG;
	sleep 0.1;
	ok( !$thread->thread, '->thread no longer exists' );
}

is( scalar( threads->list ), 0, 'One thread exists' );
