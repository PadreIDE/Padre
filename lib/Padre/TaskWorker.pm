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

our $VERSION    = '0.94';
our $COMPATIBLE = '0.91';

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
		seen  => {},
		},
		$_[0];
}

sub wid {
	$_[0]->{wid};
}

sub queue {
	$_[0]->{queue};
}

sub handle {
	my $self = shift;
	$self->{handle} = shift if @_;
	return $self->{handle};
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
	$WID2TID{ $_[0]->{wid} };
}

sub thread {
	TRACE( $_[0] ) if DEBUG;
	threads->object( $_[0]->tid );
}

sub is_thread {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->tid == threads->self->tid;
}





######################################################################
# Parent Thread Methods

# Send the worker down to (presumably) the slave master
sub send_child {
	TRACE( $_[1] ) if DEBUG;
	shift->{queue}->enqueue( [ 'child' => shift ] );
	return 1;
}

sub send_task {
	TRACE( $_[1] ) if DEBUG;
	my $self   = shift;
	my $handle = shift;

	# Tracking for the relationship between the worker and task handle
	$handle->worker( $self->wid );
	$self->{handle} = $handle->hid;
	$self->{seen}->{ $handle->class } += 1;

	# Send the message to the child
	TRACE( "Handle " . $handle->hid . " being sent to worker " . $self->wid ) if DEBUG;
	$self->{queue}->enqueue( [ 'task' => $handle->as_array ] );
	return 1;
}

sub send_message {
	TRACE( $_[1] ) if DEBUG;
	my $self = shift;

	# Freeze the who-knows-what-it-contains message for transport
	require Storable;
	my $message = Storable::nfreeze( \@_ );

	$self->{queue}->enqueue( [ 'message' => $message ] );
	return 1;
}

sub send_cancel {
	TRACE( $_[0] ) if DEBUG;
	shift->{queue}->enqueue( ['cancel'] );
	return 1;
}

# Immediately detach and terminate when queued jobs are completed
sub send_stop {
	TRACE( $_[0] ) if DEBUG;
	shift->{queue}->enqueue( ['stop'] );
	return 1;
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





######################################################################
# Child Thread Message Handlers

# Spawn a worker object off the current thread
sub child {
	TRACE( $_[0] ) if DEBUG;
	shift;
	shift->spawn;
	return 1;
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
		TRACE( "Handle " . $handle->hid . " calling ->start" ) if DEBUG;
		$handle->start( $self->queue );

		# Set up to receive thread kill signals
		local $SIG{STOP} = sub {
			die "Task aborted due to SIGSTOP from parent thread";
		};

		# Call the handle's run method
		TRACE( "Handle " . $handle->hid . " calling ->run" ) if DEBUG;
		$handle->run;

		# Tell our parent we completed successfully
		TRACE( "Handle " . $handle->hid . " calling ->stop" ) if DEBUG;
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
	TRACE("Discarding unexpected message") if DEBUG;
	return 1;
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

# Stop the current child
sub stop {
	TRACE( $_[0] ) if DEBUG;
	return 0;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
