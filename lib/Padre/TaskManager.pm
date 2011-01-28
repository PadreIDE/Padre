package Padre::TaskManager;

use 5.008005;
use strict;
use warnings;
use Params::Util             ();
use Padre::TaskHandle        ();
use Padre::TaskThread        ();
use Padre::TaskWorker        ();
use Padre::Wx                ();
use Padre::Wx::Role::Conduit ();
use Padre::Logger;

our $VERSION        = '0.80';
our $BACKCOMPATIBLE = '0.66';

# Timeout values
use constant MAX_START_TIMEOUT => 10;
use constant MAX_IDLE_TIMEOUT  => 30;

# Set up the primary integration event
our $THREAD_SIGNAL : shared;

BEGIN {
	$THREAD_SIGNAL = Wx::NewEventType();
}

sub new {
	TRACE( $_[0] ) if DEBUG;
	my $class   = shift;
	my %param   = @_;
	my $conduit = delete $param{conduit};
	my $self    = bless {
		active  => 0, # Are we running at the moment
		threads => 1, # Are threads enabled
		minimum => 0, # Workers to launch at startup
		maximum => 5, # The most workers we should use
		%param,
		workers => [], # List of all workers
		handles => {}, # Handles for all active tasks
		running => {}, # Mapping from tid back to parent handle
		queue   => [], # Pending tasks to run in FIFO order
	}, $class;

	# Do the initialisation needed for the event conduit
	unless ( Params::Util::_INSTANCE( $conduit, 'Padre::Wx::Role::Conduit' ) ) {
		die("Failed to provide an event conduit for the TaskManager");
	}
	$conduit->conduit_init($self);

	return $self;
}

sub active {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{active};
}

sub threads {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{threads};
}

sub minimum {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{minimum};
}

sub maximum {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{maximum};
}

sub start {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	if ( $self->{threads} ) {
		foreach ( 0 .. $self->{minimum} - 1 ) {
			$self->start_thread($_);
		}
	}
	$self->{active} = 1;
	$self->step;
}

sub stop {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Flag as disabled
	$self->{active} = 0;

	# Clear out the pending queue
	@{ $self->{queue} } = ();

	if ( $self->{threads} ) {
		foreach ( 0 .. $#{ $self->{workers} } ) {
			$self->stop_thread($_);
		}
		Padre::TaskThread->master->stop;
	}

	# Empty task handles
	# TODO: is this the right way of doing it?
	$self->{handles} = {};

	return 1;
}

sub start_thread {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $master = Padre::TaskThread->master;
	my $worker = Padre::TaskWorker->new->spawn;
	$self->{workers}->[ $_[0] ] = $worker;
	return $worker;
}

sub stop_thread {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $worker = delete $self->{workers}->[ $_[0] ];
	if ( $worker->handle ) {

		# Tell the worker to abandon what it is doing if it can
		if (DEBUG) {
			my $tid = $worker->tid;
			TRACE("Sending 'cancel' message to thread '$tid' before stopping");
		}
		$worker->send('cancel');
	}
	$worker->stop;
	return 1;
}

# Get the best available child for a particular task
sub best_thread {
	TRACE( $_[0] ) if DEBUG;
	my $self    = shift;
	my $handle  = shift;
	my $task    = $handle->class;
	my $workers = $self->{workers};
	my @unused  = grep { not $_->handle } @$workers;
	my @seen    = grep { $_->{seen}->{$task} } @unused;

	# Our basic strategy is to reuse an existing worker that
	# has done this task before to prevent loading more modules.
	if (@seen) {

		# Try to concentrate reuse as much as possible.
		# Pick the worker that has done the least other things.
		# Break a tie by awarding the task to the worker that has
		# done this type of task the most often to prevent flipping
		# between multiple with similar %seen diversity.
		@seen = sort {
			scalar( keys %{ $a->{seen} } ) <=> scalar( keys %{ $b->{seen} } )
				or $b->{seen}->{$task} <=> $a->{seen}->{$task}
		} @seen;
		return $seen[0];
	}

	### TODO: In future, we could also try to check for workers which
	# have seen the superclasses of our class so something which has
	# seen another LWP-based task will also be chosen for a new
	# LWP-based task.

	# If nothing has seen this task before, bias towards the least
	# specialised thread. The idea here is to try and create one
	# big generalist worker, which will maximise the likelyhood that
	# the other threads will specialise and minimise memory load by
	# having all the rare stuff in one big thread where they will
	# hopefully have shared dependencies.
	if (@unused) {
		@unused = sort { scalar( keys %{ $b->{seen} } ) <=> scalar( keys %{ $a->{seen} } ) } @unused;
		return $unused[0];
	}

	# Create a new worker if we can
	if ( @$workers < $self->maximum ) {
		return $self->start_thread( scalar @$workers );
	}

	# This task will have to wait for another worker to become free
	return undef;
}





######################################################################
# Task Management

sub schedule {
	TRACE( $_[1] ) if DEBUG;
	my $self = shift;
	my $task = Params::Util::_INSTANCE( shift, 'Padre::Task' );
	unless ($task) {
		die "Invalid task scheduled!"; # TO DO: grace
	}

	# Add to the queue of pending events
	push @{ $self->{queue} }, $task;

	# Iterate the management loop
	$self->step;
}

sub step {
	TRACE( $_[0] ) if DEBUG;
	my $self    = shift;
	my $queue   = $self->{queue};
	my $handles = $self->{handles};

	# Shortcut if not allowed to run, or nothing to do
	return 1 unless $self->{active};
	return 1 unless @$queue;

	# Shortcut if there is nowhere to run the task
	if ( $self->{threads} ) {
		if ( scalar keys %$handles >= $self->{maximum} ) {
			if ( Padre::Current->config->feature_restart_hung_task_manager ) {

				# Restart hung task manager!
				TRACE('PANIC: Restarting task manager') if DEBUG;
				$self->stop;
				$self->start;
			} else {

				# Ignore the problem and hope the user does not notice :)
				TRACE('No more task handles available. Sorry') if DEBUG;
				return 1;
			}
		}
	}

	# Fetch and prepare the next task
	my $task   = shift @$queue;
	my $handle = Padre::TaskHandle->new($task);
	my $hid    = $handle->hid;

	# Run the pre-run step in the main thread
	unless ( $handle->prepare ) {

		# Task wishes to abort itself. Oblige it.
		undef $handle;

		# Move on to the next task
		return $self->step;
	}

	# Register the handle for Wx event callbacks
	$handles->{$hid} = $handle;

	# Find the next/best worker for the task
	my $worker = $self->best_thread($handle) or return;

	# Prepare handle timing
	$handle->start_time(time);

	# Send the task to the worker for execution
	$worker->send_task($handle);

	# Continue to the next iteration
	return $self->step;
}

sub cancel {
	TRACE( $_[0] ) if DEBUG;
	my $self  = shift;
	my $owner = shift;

	# Remove any tasks from the pending queue
	@{ $self->{queue} } = grep { !defined $_->{owner} or $_->{owner} != $owner } @{ $self->{queue} };

	# Signal any active tasks to cooperatively abort themselves
	foreach my $handle ( values %{ $self->{handles} } ) {
		my $task = $handle->{task} or next;
		next unless $task->{owner};
		next unless $task->{owner} == $owner;
		foreach my $worker ( @{ $self->{workers} } ) {
			TRACE("Worker wid = $worker->{wid}")    if DEBUG;
			TRACE("Handle wid = $handle->{worker}") if DEBUG;
			next unless $worker->{wid} == $handle->{worker};
			TRACE("Sending 'cancel' message") if DEBUG;
			$worker->send('cancel');
			return 1;
		}
	}

	return 1;
}





######################################################################
# Signal Handling

sub on_signal {
	TRACE( $_[0] ) if DEBUG;
	my $self  = shift;
	my $event = shift;

	# Deserialize and squelch bad messages
	my $frozen = $event->GetData;
	my $message = eval { Storable::thaw($frozen); };
	if ($@) {
		TRACE("Exception deserialising message '$frozen'");
		return;
	}
	unless ( ref $message eq 'ARRAY' ) {
		TRACE("Unrecognised non-ARRAY message recieved from thread");
		return;
	}

	# Fine the task handle for the task
	my $hid = shift @$message;
	my $handle = $self->{handles}->{$hid} or return;

	# Update idle thread tracking so we don't force-kill this thread
	$handle->idle_time(time);

	# Handle the special startup message
	my $method = shift @$message;
	if ( $method eq 'STARTED' ) {

		# Register the task as running
		$self->{running}->{$hid} = $handle;
		return;
	}

	# Any remaining task should be running
	unless ( $self->{running}->{$hid} ) {

		# warn("Received message for a task that is not running");
		return;
	}

	# Handle the special shutdown message
	if ( $method eq 'STOPPED' ) {

		# Remove from the running list to guarantee no more events
		# will be sent to the handle (and thus to the task)
		delete $self->{running}->{$hid};

		# Free up the worker thread for other tasks
		foreach my $worker ( @{ $self->{workers} } ) {
			next unless defined $worker->handle;
			next unless $worker->handle == $hid;
			$worker->handle(undef);
			last;
		}

		# Fire the post-process/cleanup finish method, passing in the
		# completed (and serialised) task object.
		$handle->on_stopped(@$message);

		# Remove from the task list to destroy the task
		delete $self->{handles}->{$hid};

		# This should have released a worker to process
		# a new task, kick off the next scheduling iteration.
		return $self->step;
	}

	# Pass the message through to the handle
	$handle->on_message( $method, @$message );
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
