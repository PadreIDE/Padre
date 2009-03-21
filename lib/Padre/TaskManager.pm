package Padre::TaskManager;

=pod

=head1 NAME

Padre::TaskManager - Padre Background Task Scheduler

=head1 SYNOPSIS

  require Padre::Task::Foo;
  my $task = Padre::Task::Foo->new(some => 'data');
  $task->schedule(); # handed off to the task manager

=head1 DESCRIPTION

Padre uses threads for asynchroneous background operations
which may take so long that they would make the GUI unresponsive
if run in the main (GUI) thread.

This class implements a pool of a configurable number of
re-usable worker threads. Re-using threads is necessary as
the overhead of spawning threads is high. Additional threads
are spawned if many background tasks are scheduled for execution.
When the load goes down, the number of extra threads is (slowly!)
reduced down to the default.

=head1 CLASS METHODS

=head2 new

The constructor returns a C<Padre::TaskManager> object.
At the moment, C<Padre::TaskManager> is a singleton.
An object is instantiated when the editor object is created.

Optional parameters:

=over 2

=item min_no_workers / max_no_workers

Set the minimum and maximum number of worker threads
to spawn. Default: 1 to 3

The first workers are spawned lazily: I.e. only when
the first task is being scheduled.

=item use_threads

TODO: This is disabled for now since we need Wx 0.89
for stable threading.

Disable for profiling runs. In the degraded, threadless mode,
all tasks are run in the main thread. Default: 1 (use threads)

=item reap_interval

The number of milliseconds to wait before checking for dead
worker threads. Default: 15000ms

=back

=cut

use 5.008;
use strict;
use warnings;

our $VERSION = '0.29';

# According to Wx docs,
# this MUST be loaded before Wx,
# so this also happens in the script.
use threads;
use threads::shared;
use Thread::Queue;

require Padre;
use Padre::Task;
use Padre::Wx ();

use Class::XSAccessor
	getters => {
		task_queue     => 'task_queue',
		reap_interval  => 'reap_interval',
		use_threads    => 'use_threads',
		max_no_workers => 'max_no_workers',
	};

# This event is triggered by the worker thread main loop after
# finishing a task.
our $TASK_DONE_EVENT : shared = Wx::NewEventType;
# This event is triggered by the worker thread main loop before
# running a task.
our $TASK_START_EVENT : shared = Wx::NewEventType;

# remember whether the event handlers were initialized...
our $EVENTS_INITIALIZED = 0;

# Timer to reap dead workers every N milliseconds
our $REAP_TIMER;

# You can instantiate this class only once.
our $SINGLETON;

# This is set in the worker threads only!
our $_main;

sub new {
	my $class = shift;

	return $SINGLETON if defined $SINGLETON;

	my $self = $SINGLETON = bless {
		min_no_workers => 1,
		max_no_workers => 3,
		use_threads    => 1, # can be explicitly disabled
		reap_interval  => 15000,
		@_,
		workers        => [],
		task_queue     => undef,
		running_tasks  => {},
	}, $class;

	$self->{use_threads} = 0 if Wx->VERSION < 0.89;

	my $main = Padre->ide->wx->main;

	if (not $EVENTS_INITIALIZED) {
		Wx::Event::EVT_COMMAND($main, -1, $TASK_DONE_EVENT, \&on_task_done_event);
		Wx::Event::EVT_COMMAND($main, -1, $TASK_START_EVENT, \&on_task_start_event);
		Wx::Event::EVT_CLOSE($main, \&on_close);
		$EVENTS_INITIALIZED = 1;
	}
 
	$self->{task_queue} = Thread::Queue->new;

	# Set up a regular action for reaping dead workers
	# and setting up new workers
	if ( not defined $REAP_TIMER and $self->use_threads ) {
		# explicit id necessary to distinguish from startup-timer of the main window
		my $timerid = Wx::NewId();
		$REAP_TIMER = Wx::Timer->new( $main, $timerid );
		Wx::Event::EVT_TIMER(
			$main, $timerid, sub { $SINGLETON->reap(); },
		);
		$REAP_TIMER->Start( $self->reap_interval, Wx::wxTIMER_CONTINUOUS  );
	}

	return $self;
}

=pod

=head1 INSTANCE METHODS

=head2 schedule

Given a C<Padre::Task> instance (or rather an instance of a subclass),
schedule that task for execution in a worker thread.
If you call the C<schedule> method of the task object, it will
proxy to this method for convenience.

=cut

sub schedule {
	my $self = shift;
	my $task = shift;
	if ( not ref($task) or not $task->isa("Padre::Task") ) {
		die "Invalid task scheduled!"; # TODO: grace
	}

	# cleanup old threads and refill the pool
	$self->reap();
	
	# prepare and stop if vetoes
	my $return = $task->prepare();
	if ($return and $return =~ /^break$/i) {
		return;
	}

	my $string;
	$task->serialize(\$string);
	if ( $self->use_threads ) {
		require Time::HiRes;
		# This is to make sure we don't indefinitely fill the
		# queue if the CPU can't keep up. If it REALLY can't
		# keep up, we *want* to block eventually.
		# For now, the limit has been set to 5*NWORKERTHREADS
		# which should be a lot.
		while ( $self->task_queue->pending > 5 * $self->{max_no_workers} ) {
			# Sleep 10msec
			Time::HiRes::usleep(10000);
		}
		$self->task_queue->enqueue( $string );

	} else {
		# TODO: Instead of this hack, consider
		# "reimplementing" the worker loop 
		# as a non-threading, non-queued, fake worker loop
		$self->task_queue->enqueue( $string );
		$self->task_queue->enqueue( "STOP" );
		worker_loop( Padre->ide->wx->main, $self->task_queue );
	}

	return 1;
}

=pod

=head2 setup_workers

Create more workers if necessary. Called by C<reap> which
is called regularly by the reap timer, so users don't
typically need to call this.

=cut

sub setup_workers {
	my $self = shift;
	return unless $self->use_threads;

	@_=(); # avoid "Scalars leaked"
	my $main = Padre->ide->wx->main;

	# Ensure minimum no. workers
	my $workers = $self->{workers};
	while (@$workers < $self->{min_no_workers}) {
		$self->_make_worker_thread($main);
	}

	# Add workers to satisfy demand
	my $jobs_pending = $self->task_queue->pending();
	if (@$workers < $self->{max_no_workers} and $jobs_pending > 2*@$workers) {
		my $target = int($jobs_pending/2);
		$target = $self->{max_no_workers} if $target > $self->{max_no_workers};
		$self->_make_worker_thread($main) for 1..($target-@$workers);
	}

	return 1;
}

# short method to create a new thread
sub _make_worker_thread {
	my $self = shift;
	my $main = shift;
	return if not $self->use_threads;

	@_=(); # avoid "Scalars leaked"
	my $worker = threads->create(
	  {'exit' => 'thread_only'}, \&worker_loop, $main, $self->task_queue
	);
	push @{$self->{workers}}, $worker;
}

=pod

=head2 reap

Check for worker threads that have exited and can be joined.
If there are more worker threads than the normal number and
they are idle, one worker thread (per C<reap> call) is
stopped.

This method is called regularly by the reap timer (see
the C<reap_interval> option to the constructor) and it's not
typically called by users.

=cut

sub reap {
	my $self = shift;
	return if not $self->use_threads;

	@_=(); # avoid "Scalars leaked"
	my $workers = $self->{workers};

	my @active_or_waiting;
	#warn "No. worker threads before reaping: ".scalar (@$workers);

	foreach my $thread (@$workers) {
		if ($thread->is_joinable()) {
			my $tmp = $thread->join();
		}
		else {
			push @active_or_waiting, $thread;
		}
	}
	$self->{workers} = \@active_or_waiting;
	#warn "No. worker threads after reaping:  ".scalar (@$workers);

	# kill the no. of workers that aren't needed
	my $n_threads_to_kill =  @active_or_waiting - $self->{max_no_workers};
	$n_threads_to_kill = 0 if $n_threads_to_kill < 0;
	my $jobs_pending = $self->task_queue->pending();

	# slowly reduce the no. workers to the minimum
	$n_threads_to_kill++
	  if @active_or_waiting-$n_threads_to_kill > $self->{min_no_workers}
	  and $jobs_pending == 0;
	
	if ($n_threads_to_kill) {
		# my $target_n_threads = @active_or_waiting - $n_threads_to_kill;
		my $queue = $self->task_queue;
		$queue->insert( 0, ("STOP") x $n_threads_to_kill )
		  unless $queue->pending() and not ref($queue->peek(0));

		# We don't actually need to wait for the soon-to-be-joinable threads
		# since reap should be called regularly.
		#while (threads->list(threads::running) >= $target_n_threads) {
		#  $_->join for threads->list(threads::joinable);
		#}
	}

	$self->setup_workers();

	return 1;
}

=pod

=head2 cleanup

Stops all worker threads. Called on editor shutdown.

=cut

sub cleanup {
	my $self = shift;
	return if not $self->use_threads;

	# the nice way:
	my @workers = $self->workers;
	$self->task_queue->insert( 0, ("STOP") x scalar(@workers) );
	while (threads->list(threads::running) >= 1) {
		$_->join for threads->list(threads::joinable);
	}
	$_->join for threads->list(threads::joinable);

	# didn't work the nice way?
	while (threads->list(threads::running) >= 1) {
		$_->detach(), $_->kill() for threads->list(threads::running);
	}

	return 1;
}

=pod

=head1 ACCESSORS

=head2 task_queue

Returns the queue of tasks to be processed as a
L<Thread::Queue> object. The tasks in the
queue have been serialized for passing between threads,
so this is mostly useful internally or
for checking the number of outstanding jobs.

=head2 reap_interval

Returns the number of milliseconds between the
regulary cleanup runs.

=head2 use_threads

Returns whether running in degraded mode (no threads, false)
or normal operation (threads, true).

=head2 running_tasks

Returns the number of tasks that are currently being executed.

=cut

sub running_tasks {
	my $self = shift;
	my $n = 0;
	foreach my $tasks_of_this_type (values %{$self->{running_tasks}}) {
		$n += $tasks_of_this_type;
	}
	return $n;
}

=pod

=head2 workers

Returns B<a list> of the worker threads.

=cut

sub workers {
	my $self = shift;
	return @{$self->{workers}};
}

=pod

=head1 EVENT HANDLERS

=head2 on_close

Registered to be executed on editor shutdown.
Executes the cleanup method.

=cut

sub on_close {
	my ($main, $event) = @_; @_ = (); # hack to avoid "Scalars leaked"

	# TODO/FIXME:
	# This should somehow get at the specific TaskManager object
	# instead of going through the Padre globals!
	Padre->ide->{task_manager}->cleanup();

	$event->Skip(1);
}

=pod

=head2 on_task_done_event

This event handler is called when a background task has
finished execution. It deserializes the background task
object and calls its C<finish> method with the
Padre main window object as first argument. (This is done
because C<finish> most likely updates the GUI.)

=cut

sub on_task_done_event {
	my ($main, $event) = @_; @_ = (); # hack to avoid "Scalars leaked"
	my $frozen = $event->GetData;
	my $task = Padre::Task->deserialize( \$frozen );

	$task->finish($main);

	# TODO/FIXME:
	# This should somehow get at the specific TaskManager object
	# instead of going through the Padre globals!
	my $running = Padre->ide->task_manager->{running_tasks};
	my $task_type = ref($task);
	warn "DONE: $task_type";
	$running->{$task_type}--;
	delete $running->{$task_type} if not $running->{$task_type};
	
	$main->GetToolBar->update_task_status();

	return();
}

=pod

=head2 on_task_start_event

This event handler is called when a background task is about to start
execution.
It simply increments the running task counter.

=cut

sub on_task_start_event {
	my ($main, $event) = @_; @_ = (); # hack to avoid "Scalars leaked"
	# TODO/FIXME:
	# This should somehow get at the specific TaskManager object
	# instead of going through the Padre globals!
	my $manager = Padre->ide->task_manager;
	my $task_type = $event->GetData();
	$manager->{running_tasks}{$task_type}++;
	warn "STARTED: $task_type";
	$main->GetToolBar->update_task_status();

	return();
}

##########################
# Worker thread main loop
sub worker_loop {
	my ($main, $queue) = @_;  @_ = (); # hack to avoid "Scalars leaked"
	require Storable;

	# Set the thread-specific main-window pointer
	$_main = $main;

	#warn threads->tid() . " -- Hi, I'm a thread.";

	while (my $frozen_task = $queue->dequeue ) {

		#warn threads->tid() . " -- got task.";

		#warn("THREAD TERMINATING"), return 1 if not ref($task) and $task eq 'STOP';
		return 1 if not ref($frozen_task) and $frozen_task eq 'STOP';

		my $task = Padre::Task->deserialize( \$frozen_task );

		my $thread_start_event = Wx::PlThreadEvent->new( -1, $TASK_START_EVENT, ref($task) );
		Wx::PostEvent($main, $thread_start_event);
		
		# RUN
		$task->run();

		# FREEZE THE PROCESS AND PASS IT BACK
		undef $frozen_task;
		$task->serialize( \$frozen_task );

		my $thread_done_event = Wx::PlThreadEvent->new( -1, $TASK_DONE_EVENT, $frozen_task );
		Wx::PostEvent($main, $thread_done_event);

		#warn threads->tid() . " -- done with task.";
	}
	
	# clean up
	undef $_main;
}


1;

=pod

=head1 TODO

What if the computer can't keep up with the queued jobs? This needs
some consideration and probably, the schedule() call needs to block once
the queue is "full". However, it's not clear how this can work if the
Wx MainLoop isn't reached for processing finish events.

=head1 SEE ALSO

The base class of all "work units" is L<Padre::Task>.

=head1 AUTHOR

Steffen Mueller C<smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
