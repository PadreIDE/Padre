package Padre::TaskWorker;

# Cleanly encapsulated object for a thread that does work based
# on packaged method calls passed via a shared queue.

use 5.008005;
use strict;
use warnings;
use Scalar::Util     ();
use Padre::TaskQueue ();

# NOTE: The TRACE() calls in this class should be commented out unless
# actively debugging, so that the Padre::Logger class will only be loaded in
# the parent thread AFTER the threads spawn.
# use Padre::Logger;
use constant DEBUG => 0;

our $VERSION = '0.91';

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





######################################################################
# Constructor and Accessors

sub new {
	TRACE( $_[0] ) if DEBUG;
	bless {
		wid   => ++$SEQUENCE,
		queue => Padre::TaskQueue->new,
		seen  => { },
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
		{ context => 'void' },
		sub {
			shift->run;
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





######################################################################
# Parent Thread Methods

sub send {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $method = shift;
	unless ( $self->can($method) ) {
		die("Attempted to send message to non-existant method '$method'");
	}

	# Add the message to the queue
	TRACE("Calling enqueue '$method'") if DEBUG;
	$self->{queue}->enqueue( [ $method, @_ ] );
	TRACE("Completed enqueue '$method'") if DEBUG;

	return 1;
}

sub send_task {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $handle = shift;

	# Tracking for the relationship between the worker and task handle
	$handle->worker( $self->wid );
	$self->{handle} = $handle->hid;
	$self->{seen}->{ $handle->class } += 1;

	# Send the message to the child
	TRACE( "Handle " . $handle->hid . " being sent to worker " . $self->wid ) if DEBUG;
	$self->send( 'task', $handle->as_array );
}

sub handle {
	my $self = shift;
	$self->{handle} = shift if @_;
	return $self->{handle};
}

# Add a worker object to the pool, spawning it from the master
sub start {
	TRACE( $_[0] ) if DEBUG;
	shift->send( 'start_child', @_ );
}

# Immediately detach and terminate when queued jobs are completed
sub stop {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $thread = $self->thread;
	if ( defined $thread ) {
		TRACE("Thread is still alive") if DEBUG;
	} else {
		TRACE("No thread object...?") if DEBUG;
	}
	$self->send('stop_child');
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
			next;
		}

		# Check the message type
		TRACE("Worker received message '$message->[0]'") if DEBUG;
		my $method = shift @$message;
		next unless $self->can($method);

		# Hand off to the appropriate method.
		# Methods must return true, otherwise the thread
		# will abort processing and end.
		$self->$method(@$message) or last;
	}

	TRACE("Exiting worker run-time loop") if DEBUG;
	return;
}

# Spawn a worker object off the current thread
sub start_child {
	TRACE($_[0]) if DEBUG;
	shift;
	shift->spawn;
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
	my $self = shift;

	# Deserialize the task handle
	TRACE("Loading Padre::TaskHandle") if DEBUG;
	require Padre::TaskHandle;
	TRACE("Inflating handle object") if DEBUG;
	my $handle = Padre::TaskHandle->from_array(shift);

	# Execute the task (ignore the result) and signal as we go
	local $@;
	eval {
		# Tell our parent we are starting
		TRACE("Handle " . $handle->hid . " calling ->start") if DEBUG;
		$handle->start($self->queue);

		# Set up to receive thread kill signals
		local $SIG{STOP} = sub {
			die "Task aborted due to SIGSTOP from parent thread";
		};

		# Call the handle's run method
		TRACE("Handle " . $handle->hid . " calling ->run") if DEBUG;
		$handle->run;

		# Tell our parent we completed successfully
		TRACE("Handle " . $handle->hid . " calling ->stop") if DEBUG;
		$handle->stop;
	};
	if ($@) {
		delete $handle->{queue};
		delete $handle->{child};
		TRACE($@) if DEBUG;
	}

	return 1;
}

# A message for the active task that arrive when we are NOT actively running a
# task should be discarded with no consequence.
sub message {
	TRACE( $_[0] ) if DEBUG;
	TRACE("Discarding message '$_[1]->[0]'") if DEBUG;
}

# A cancel request that arrives when we are NOT actively running a task
# should be discarded with no consequence.
sub cancel {
	if (DEBUG) {
		TRACE( $_[0] );
		if ( defined $_[1]->[0] ) {
			TRACE("Discarding cancel '$_[1]->[0]'");
		} else {
			TRACE("Discarding undefined message");
		}
	}
	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
