package Padre::TaskThread;

# Cleanly encapsulated object for a thread that does work based
# on packaged method calls passed via a shared queue.

use 5.008005;
use strict;
use warnings;
use Scalar::Util     ();
use Padre::TaskQueue ();

# NOTE: The TRACE() calls in this class should be commented out unless
# actively debugging, so that the Padre::Logger class will only be
# loaded AFTER the threads spawn.
use Padre::Logger;

# use constant DEBUG => 0;

our $VERSION = '0.90';

# Worker id sequence, so identifiers will be available in objects
# across all instances and threads before the thread has been spawned.
# We map the worker ID to the thread id, once it exists.
my $SEQUENCE : shared = 0;
my %WID2TID : shared  = ();





######################################################################
# Slave Master Support (main thread only)

my $SINGLETON = undef;

sub master {
	$SINGLETON or $SINGLETON = shift->new->spawn;
}

sub master_running {
	!!$SINGLETON;
}

# Handle master initialisation
sub import {
	if ( defined $_[1] and $_[1] eq ':master' ) {
		$_[0]->master;
	}
}





######################################################################
# Constructor and Accessors

sub new {
	TRACE( $_[0] ) if DEBUG;
	bless {
		wid   => ++$SEQUENCE,
		queue => Padre::TaskQueue->new,
		},
		$_[0];
}

sub wid {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->{wid};
}

sub queue {
	TRACE( $_[0] ) if DEBUG;
	TRACE( $_[0]->{queue} ) if DEBUG;
	$_[0]->{queue};
}





######################################################################
# Main Methods

sub spawn {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Spawn the object into the thread and enter the main runloop
	$WID2TID{ $self->{wid} } = threads->create(
		sub {

			# We need to load the worker class even though we
			# already have an instance of it.
			my $worker = Scalar::Util::blessed( $_[0] );
			SCOPE: {
				local $@;
				eval "require $worker;";
				die $@ if $@;
			}

			# Start the worker runloop
			$_[0]->run;
		},
		$self,
	)->tid;

	return $self;
}

sub tid {
	TRACE( $_[0] ) if DEBUG;
	$WID2TID{ $_[0]->{wid} };
}

sub thread {
	TRACE( $_[0] ) if DEBUG;
	threads->object( $_[0]->tid );
}

sub join {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->thread->join;
}

sub is_thread {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->tid == threads->self->tid;
}

sub is_running {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->thread->is_running;
}

sub is_joinable {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->thread->is_joinable;
}

sub is_detached {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->thread->is_detached;
}





######################################################################
# Parent Thread Methods

sub send {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $method = shift;
	unless ( _CAN( $self, $method ) ) {
		die("Attempted to send message to non-existant method '$method'");
	}

	# Add the message to the queue
	TRACE("Calling enqueue '$method'") if DEBUG;
	$self->{queue}->enqueue( [ $method, @_ ] );
	TRACE("Completed enqueue '$method'") if DEBUG;

	return 1;
}

# Add a worker object to the pool, spawning it from the master
sub start {
	TRACE( $_[0] ) if DEBUG;
	shift->send( 'start_child', @_ );
}

# Immediately detach and terminate when queued jobs are completed
sub stop {
	TRACE( $_[0] )            if DEBUG;
	TRACE("Detaching thread") if DEBUG;
	$_[0]->thread->detach     if defined( $_[0]->thread );
	$_[0]->send('stop_child');
}





######################################################################
# Child Thread Methods

sub run {
	TRACE( $_[0] ) if DEBUG;
	my $self  = shift;
	my $queue = $self->{queue};

	# Loop over inbound requests
	TRACE("Entering worker run-time loop") if DEBUG;
	while (1) {
		my $message = $queue->dequeue1;
		unless ( ref $message eq 'ARRAY' and @$message ) {

			# warn("Message is not an ARRAY reference");
			next;
		}

		# Check the message type
		TRACE("Worker received message '$message->[0]'") if DEBUG;
		my $method = shift @$message;
		unless ( _CAN( $self, $method ) ) {

			# warn("Illegal message type");
			next;
		}

		# Hand off to the appropriate method.
		# Methods must return true, otherwise the thread
		# will abort processing and end.
		$self->$method(@$message) or last;
	}

	TRACE("Exited worker run-time loop") if DEBUG;
	return;
}





######################################################################
# Message Handlers

# Spawn a worker object off the current thread
sub start_child {
	TRACE( $_[0] ) if DEBUG;

	# HACK: This is pretty darned evil, but the slave master thread won't
	# have Padre::ThreadWorker loaded, so it can't invoke ->spawn as a
	# method. As long as Padre::ThreadWorker never implements it's own
	# overridden ->spawn method, this hack is valid. We use the fully
	# resolved function name even though we're in the same class just to
	# make it clear we're doing something pretty evil.
	# $_[1]->spawn;
	Padre::TaskThread::spawn( $_[1] );

	return 1;
}

# Stop the current child
sub stop_child {
	TRACE( $_[0] ) if DEBUG;
	return 0;
}

# Execute a task
sub task {
	TRACE( $_[0] ) if DEBUG;
	require Padre::TaskHandle;
	Padre::TaskHandle->from_array( $_[1] );
}





######################################################################
# Support Methods

sub _CAN {
	( Scalar::Util::blessed( $_[0] ) and $_[0]->can( $_[1] ) ) ? $_[0] : undef;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
