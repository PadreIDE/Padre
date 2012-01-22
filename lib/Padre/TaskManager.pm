package Padre::TaskManager;

=pod

=head1 NAME

Padre::TaskManager - Padre Background Task and Service Manager

=head1 DESCRIPTION

The B<Padre Task Manager> is responsible for scheduling, queueing and
executing all operations that do not occur in the main application thead.

While there is rarely any need for code elsewhere in Padre or a plugin to make
calls to this API, documentation is included for maintenance purposes.

It spawns and manages a pool of workers which act as containers for the
execution of standalone serialisable tasks. This execution model is based
loosely on the CPAN L<Process> API, and involves the parent process creating
L<Padre::Task> objects representing the work to do. These tasks are serialised
to a bytestream, passed down a shared queue to an appropriate worker,
deserialised back into an object, executed, and then reserialised for
transmission back to the parent thread.

=head2 Task Structure

Tasks operate on a shared-nothing basis. Each worker is required to
reload any modules needed by the task, and the task cannot access any of the
data structures. To compensate for these limits, tasks are able to send messages
back and forth between the instance of the task object in the parent and
the instance of the same task in the child.

Using this messaging channel, a task object in the child can send status
message or incremental results up to the parent, and the task object in the
parent can make changes to the GUI based on these messages.

The same messaging channel allows a background task to be cancelled elegantly
by the parent, although support for the "cancel" message is voluntary on
the part of the background task.

=head2 Service Structure

Services are implemented via the L<Padre::Service> API. This is nearly
identical to, and sub-classes directly, the L<Padre::Task> API.

The main difference between a task and a service is that a service will be
allocated a private, unused and dedicated worker that has never been
used by a task. Further, workers allocated to services will also not be counted
against the "maximum workers" limit.

=head1 METHODS

=cut

use 5.008005;
use strict;
use warnings;
use Params::Util      ();
use Padre::Config     ();
use Padre::Current    ();
use Padre::TaskHandle ();
use Padre::TaskWorker ();
use Padre::Logger;

our $VERSION    = '0.94';
our $COMPATIBLE = '0.81';

# Timeout values
use constant {
	MAX_START_TIMEOUT => 10,
	MAX_IDLE_TIMEOUT  => 30,
};





######################################################################
# Constructor and Accessors

# NOTE: To keep dependencies down in this general area in case of a future
#       spin-off CPAN module do NOT port accessors below to Class::XSAccessor.

=pod

=head2 new

    my $manager = Padre::TaskManager->new(
        conduit => $message_conduit,
    );  

The C<new> constructor creates a new Task Manager instance. While it is
theoretically possible to create more than one instance, in practice this
is never likely to occur.

The constructor has a single compulsory parameter, which is an object that
implements the "message conduit" role L<Padre::Wx::Role::Conduit>.

The message conduit is an object which provides direct integration with the
underlying child-to-parent messaging pipeline, which in L<Padre> is done via
L<Wx::PlThreadEvent> thread events.

Because the message conduit is provided to the constructor, the Task Manager
itself is able to function with no L<Wx>-specific code whatsoever. This
simplifies implementation, allows sophisticated test rigs to be created,
and makes it easier for us to spin off the Task Manager as a some notional
standalone CPAN module.

=cut

sub new {
	TRACE( $_[0] ) if DEBUG;
	my $class   = shift;
	my %param   = @_;
	my $conduit = delete $param{conduit} or die "Failed to provide event conduit";
	my $self    = bless {
		active  => 0, # Are we running at the moment
		threads => 1, # Are threads enabled
		maximum => 5, # The most workers we should use
		%param,
		workers => [], # List of all workers
		handles => {}, # Handles for all active tasks
		running => {}, # Mapping from tid back to parent handle
		queue   => [], # Pending tasks to run in FIFO order
		locks   => {}, # Tracks consumed locks
	}, $class;

	# Do the initialisation needed for the event conduit
	$conduit->conduit_init($self);

	return $self;
}

=pod

=head2 active

The C<active> accessor returns true if the task manager is currently running,
or false if not. Generally task manager startup will occur relatively early
in the Padre startup sequence, and task manager shutdown will occur relatively
early in the shutdown sequence (to prevent accidental task execution during
shutdown).

=cut

sub active {
	$_[0]->{active};
}

=pod

=head2 maximum

The C<maximum> accessor returns the maximum quantity of worker threads that the
task manager will use for running ordinary finite-length tasks. Once the number
of active workers reaches the C<maximum> limit, futher tasks will be pushed
onto a queue to wait for a free worker.

=cut

sub maximum {
	$_[0]->{maximum};
}





######################################################################
# Main Methods

=pod

=head2 start

    $manager->start;

The C<start> method bootstraps the task manager, creating the master thread.

=cut

sub start {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Start the master if it wasn't pre-launched
	if ( $self->{threads} ) {
		unless ( Padre::TaskWorker->master_running ) {
			Padre::TaskWorker->master;
		}
	}

	# We are now active
	$self->{active} = 1;

	# Take one initial spin through the dispatch loop to run anything
	# that queued up before we were started.
	$self->run;
}

=pod

=head2 stop

    $manager->stop;

The C<stop> method shuts down the task manager, signalling active workers that
they should do an elegant shutdown.

=cut

sub stop {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Disable and clear pending tasks
	$self->{active} = 0;
	$self->{queue}  = [];

	# Shut down the master thread
	# NOTE: We ignore the status of the thread master settings here and
	# act only on the basis of whether or not a master thread is running.
	if ($Padre::TaskWorker::VERSION) {
		if ( Padre::TaskWorker->master_running ) {
			Padre::TaskWorker->master->send_stop;
		}
	}

	# Stop all of our workers
	foreach ( 0 .. $#{ $self->{workers} } ) {
		$self->stop_worker($_);
	}

	# Empty task handles
	# TODO: is this the right way of doing it?
	$self->{handles} = {};

	return 1;
}

=pod

=head2 schedule

The C<schedule> method is used to give a task to the task manager and indicate
it should be run as soon as possible.

This may be immediately (with the task sent to a worker before the method
returns) or it may be delayed until some time in the future if all workers
are busy.

As a convenience, this method returns true if the task could be dispatched
immediately, or false if it was queued for future execution.

=cut

sub schedule {
	TRACE( $_[1] ) if DEBUG;
	my $self = shift;
	my $task = Params::Util::_INSTANCE( shift, 'Padre::Task' );
	unless ($task) {
		die "Invalid task scheduled!"; # TO DO: grace
	}

	# Add to the queue of pending events
	push @{ $self->{queue} }, $task;

	# Dispatch this task and anything else waiting from a previous call.
	$self->run;
}

=pod

=head2 cancelled

    $manager->cancelled( $owner );

The C<cancelled> method is used with the "task ownership" feature of the
L<Padre::Task> 3.0 API to signal tasks running in the background that
were created by a particular object that they should voluntarily abort as
their results are no longer wanted.

=cut

sub cancel {
	TRACE( $_[0] ) if DEBUG;
	my $self  = shift;
	my $owner = shift;
	my $queue = $self->{queue};

	# Remove any tasks from the pending queue
	@$queue = grep { !defined $_->{owner} or $_->{owner} != $owner } @$queue;

	# Signal any active tasks to cooperatively abort themselves
	foreach my $handle ( values %{ $self->{handles} } ) {
		my $task = $handle->{task} or next;
		next unless $task->{owner};
		next unless $task->{owner} == $owner;
		$handle->cancel;
		foreach my $worker ( grep { defined $_ } @{ $self->{workers} } ) {
			next unless defined $handle->{worker};
			next unless $worker->{wid} == $handle->{worker};
			TRACE("Sending 'cancel' message to worker $worker->{wid}") if DEBUG;
			$worker->send_cancel;
			return 1;
		}
	}

	return 1;
}





######################################################################
# Support Methods

=pod

=head2 start_worker

    my $worker = $manager->start_worker;

The C<start_worker> starts and returns a new registered L<Padre::TaskWorker>
object, ready to execute a task or service in.

You generally should never need to call this method from outside
B<Padre::TaskManager>.

=cut

sub start_worker {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	unless ( Padre::TaskWorker->master_running ) {
		die "Master thread is unexpectedly not running";
	}

	# Start the worker via the master.
	my $worker = Padre::TaskWorker->new;
	Padre::TaskWorker->master->send_child($worker);
	push @{ $self->{workers} }, $worker;
	return $worker;
}

=pod

=head2 stop_worker

    $manager->stop_worker(1);

The C<stop_worker> method shuts down a single worker, which (unfortunately) at
this time is indicated via the internal index position in the workers array.

=cut

sub stop_worker {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $worker = delete $self->{workers}->[ $_[0] ];
	if ( $worker->handle ) {

		# Tell the worker to abandon what it is doing
		if (DEBUG) {
			my $tid = $worker->tid;
			TRACE("Sending 'cancel' message to thread '$tid' before stopping");
		}
		$worker->send_cancel;
	}
	$worker->send_stop;
	return 1;
}

=pod

=head2 kill_worker

    $manager->kill_worker(1);

The C<kill_worker> method forcefully and immediately terminates a worker,
and like C<stop_worker> the worker to kill is indicated by the internal
index position within the workers array.

B<This method is not yet in use, the Task Manager does not current have the
ability to forcefully terminate workers.>

=cut

sub kill_worker {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $worker = delete $self->{workers}->[ $_[0] ] or return;

	# Send a sigstop to the worker thread, if it is running
	my $thread = $worker->thread or return;
	$thread->kill('STOP');
}

=pod

=head2 run

The C<run> method tells the Task Manager to sweep the queue of pending tasks
and dispatch as many as possible to worker threads.

Generally you should never need to call this method directly, as it will be
called whenever you schedule a task or when a worker becomes available.

Returns true if all pending tasks were dispatched, or false if any tasks
remain on the queue.

=cut

sub run {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Do nothing if we somehow arrive here when the task manager isn't on.
	return 1 unless $self->{active};

	# Try to dispatch tasks until we run out
	my $queue   = $self->{queue};
	my $handles = $self->{handles};
	my $i       = 0;
	while (@$queue) {
		last if $i > $#$queue;

		# Shortcut if there is nowhere to run the task
		if ( $self->{threads} ) {
			if ( scalar keys %$handles >= $self->{maximum} ) {
				TRACE('No more task handles available') if DEBUG;
				return;
			}
		}

		# Can we execute the task at this position in the queue?
		unless ( $self->good_task($queue->[$i]) ) {
			$i++;
			next;
		}

		# Prepare the confirmed-good task
		my $task   = splice( @$queue, $i, 1 );
		my $handle = Padre::TaskHandle->new($task);
		unless ( $handle->prepare ) {

			# Task wishes to abort itself. Oblige it.
			undef $handle;

			# Move on to the next task
			next;
		}

		# Register the handle for child messages
		my $hid = $handle->hid;
		TRACE("Handle $hid registered for messages") if DEBUG;
		$handles->{$hid} = $handle;

		if ( $self->{threads} ) {

			# Find the next/best worker for the task
			my $worker = $self->best_worker($handle);
			if ($worker) {
				TRACE( "Handle $hid allocated worker " . $worker->wid ) if DEBUG;
			} else {
				TRACE("Handle $hid has no worker") if DEBUG;
				return;
			}

			# Prepare handle timing
			$handle->start_time(time);

			# Send the task to the worker for execution
			$worker->send_task($handle);

		} else {

			# Prepare handle timing
			$handle->start_time(time);

			# Clone the handle so we don't impact the original
			my $copy = Padre::TaskHandle->from_array( $handle->as_array );

			# Execute the task (ignore the result) and signal as we go
			local $@;
			eval {
				TRACE( "Handle " . $copy->hid . " calling ->start" ) if DEBUG;
				$copy->start( [] );
				TRACE( "Handle " . $copy->hid . " calling ->run" ) if DEBUG;
				$copy->run;
				TRACE( "Handle " . $copy->hid . " calling ->stop" ) if DEBUG;
				$copy->stop;
			};
			if ($@) {
				delete $copy->{queue};
				delete $copy->{child};
				TRACE($@) if DEBUG;
			}
		}
	}

	return 1;
}

=pod

=head2 good_task

    my $ok = $manager->good_task($task);

The C<good_task> method takes a L<Padre::Task> object and determines if the
task can be executed, given the resources available to the task manager.

Returns a L<Padre::Task> object, or C<undef> if there is no task to execute.

=cut

sub good_task {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;

	return 1;
}

=pod

=head2 best_worker

    my $worker = $manager->best_worker( $task_object );

The C<best_worker> method is used to find the best worker from the worker pool
for the execution of a particular task object.

This method makes use of a number of different strategies for optimising the
way in which workers are used, such as maximising worker reuse for the same
type of task, and "specialising" workers for particular types of tasks.

If all existing workers are in use this method may also spawn new workers,
up to the C<maximum> worker limit. Without the slave master logic enabled this
will result in the editor blocking in the foreground briefly, this is something
we can live with until the slave master feature is working again.

Returns a L<Padre::TaskWorker> object, or C<undef> if there is no worker in
which the task can be run.

=cut

sub best_worker {
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
		return $self->start_worker;
	}

	# This task will have to wait for another worker to become free
	return undef;
}

=pod

=head2 on_signal

    $manager->on_signal( \@message );

The C<on_signal> method is called from the conduit object and acts as a
central distribution mechanism for messages coming from all child workers.

Messages arrive as a list of elements in an C<ARRAY> with their first element
being the handle identifier of the L<Padre::TaskHandle> for the task.

This "envelope" element is stripped from the front of the message, and the
remainder of the message is passed down into the handle (and the task within
the handle).

Certain special messages, such as "STARTED" and "STOPPED" are emitted not by
the task but by the surrounding handle, and indicate to the task manager the
state of the child worker.

=cut

sub on_signal {
	TRACE( $_[0] ) if DEBUG;
	my $self    = shift;
	my $message = shift;
	unless ( $self->{active} ) {
		TRACE("Ignoring message while not active") if DEBUG;
		return;
	}
	unless ( Params::Util::_ARRAY($message) ) {
		TRACE("Unrecognised non-ARRAY or empty message") if DEBUG;
		return;
	}

	# Find the task handle for the task
	my $hid    = shift @$message;
	my $handle = $self->{handles}->{$hid};
	unless ($handle) {
		TRACE("Handle $hid does not exist...") if DEBUG;
		return;
	}

	# Update idle tracking so we don't force-kill this worker
	$handle->idle_time(time);

	# Handle the special startup message
	my $method = shift @$message;
	if ( $method eq 'STARTED' ) {

		# Register the task as running
		TRACE("Handle $hid added to 'running'...") if DEBUG;
		$self->{running}->{$hid} = $handle;

		# Fire the task startup handler so the parent instance of the
		# task (or our owner) knows they can send messages to it now.
		$handle->on_started(@$message);

		return;
	}

	# Any remaining task should be running
	unless ( $self->{running}->{$hid} ) {
		TRACE("Handle $hid is not running to receive '$method'") if DEBUG;
		return;
	}

	# Handle the special shutdown message
	if ( $method eq 'STOPPED' ) {

		# Remove from the running list to guarantee no more events
		# will be sent to the handle (and thus to the task)
		TRACE("Handle $hid removed from 'running'...") if DEBUG;
		delete $self->{running}->{$hid};

		# Free up the worker for other tasks
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
		TRACE("Handle $hid completed on_stopped...") if DEBUG;
		delete $self->{handles}->{$hid};

		# This should have released a worker to process
		# a new task, kick off the next scheduling iteration.
		$self->run;
		return;
	}

	# Pass the message through to the handle
	$handle->on_message( $method, @$message );
}

sub waitjoin {
	TRACE( $_[0] ) if DEBUG;

	foreach ( 0 .. 9 ) {
		my $more = 0;

		# Close the threads in LIFO order, just in case it matters
		foreach my $thread ( reverse threads->list ) {
			if ( $thread->is_joinable ) {
				TRACE( "Thread " . $thread->tid . " joining..." ) if DEBUG;
				$thread->join;
			} else {
				TRACE( "Thread " . $thread->tid . " not joinable" ) if DEBUG;
				$more++;
			}
		}
		unless ($more) {
			TRACE("All threads joined") if DEBUG;
			last;
		}

		# Wait a short time to let the other thread exit
		require Time::HiRes;
		Time::HiRes::sleep(0.1);
	}

	return 1;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
