package Padre::SlaveDriver;

=pod

=head1 NAME

Padre::SlaveDriver - Padre thread spawning

=head1 SYNOPSIS

  use Padre::SlaveDriver;
  my $sd = Padre::SlaveDriver->new();
  my $slave_thread = $sd->spawn($taskManager);

=head1 DESCRIPTION

Padre uses threads for asynchronous background operations
which may take so long that they would make the GUI unresponsive
if run in the main (GUI) thread.

This class is a helper that will spawn new worker on demand. It
keeps a single model thread around that was (or should have been)
created very early in the start-up process of Padre. Therefore,
the threads' memory consumption will be significantly lower than
if one created new worker (slave) threads from the main Padre thread.

Maintainer note: This module must not load any other part of Padre
and should generally be kept low on memory overhead.

=head1 INTERFACE

=head2 Class Methods

=cut

use 5.008005;
use strict;
use warnings;
use threads;
use threads::shared;

# This has a version to prevent known cases of people not upgrading
use Thread::Queue 2.11;

our $VERSION = '0.64';

# This event is triggered by the worker thread main loop after
# finishing a task.
our $TASK_DONE_EVENT : shared;

# This event is triggered by the worker thread main loop before
# running a task.
our $TASK_START_EVENT : shared;

=pod

=head3 C<new>

The constructor returns a C<Padre::SlaveDriver> object.
C<Padre::SlaveDriver> is a singleton.

An object is instantiated when the editor object is created.

=cut

SCOPE: {
	my $SlaveDriver;

	sub new {
		return $SlaveDriver if defined $SlaveDriver;

		my $class = shift;
		@_ = ();

		$SlaveDriver = bless {
			cmd_queue  => Thread::Queue->new,
			tid_queue  => Thread::Queue->new,
			task_queue => Thread::Queue->new,
		} => $class;

		# Wx must be loaded before this code fires
		require Wx;
		require Wx::Event;
		$TASK_DONE_EVENT  = Wx::NewEventType() unless defined $TASK_DONE_EVENT;
		$TASK_START_EVENT = Wx::NewEventType() unless defined $TASK_START_EVENT;

		# Because the following code spawns the slave master,
		# we need to wrap an database anti-lock around it.
		my $locked = Padre::DB->can('connected') && Padre::DB->connected;
		Padre::DB->commit if $locked;

		# Create the "slave master" top level thread.
		$SlaveDriver->{master} = threads->create(
			\&_slave_driver_loop,
			$SlaveDriver->{cmd_queue},
			$SlaveDriver->{tid_queue}
		);

		# If we were previously in a database lock restore it
		# so that lock management doesn't freak out.
		Padre::DB->begin if $locked;

		return $SlaveDriver;
	}

	END {
		if ( defined $SlaveDriver ) {
			$SlaveDriver->cleanup;
			undef $SlaveDriver;
		}
	}
}

=pod

=head2 Object methods

=head3 C<spawn>

Takes the L<Padre::TaskManager> object as argument.
Returns a new worker thread object.

=cut

sub spawn {
	my $self    = shift;
	my $manager = shift;

	require Storable;
	$self->{cmd_queue}->enqueue( Storable::freeze( [ $manager->task_queue ] ) );

	return threads->object( $self->{tid_queue}->dequeue );
}

=pod

=head3 C<task_queue>

Returns the task queue (C<Thread::Queue> object) for use by the
L<Padre::TaskManager> for passing processing tasks to the worker
threads.

This queue is instantiated by the slave driver because it needs to be available
early for passing to the master thread.

=cut

sub task_queue {
	$_[0]->{task_queue};
}

=pod

=head3 C<cleanup>

Reaps the master thread. Will be called by the C<TaskManager> on shutdown and
on global destruction.

=cut

sub cleanup {
	my $self = shift;

	if ( defined $self->{master} and defined $self->{cmd_queue} ) {
		$self->{cmd_queue}->enqueue('STOP');

		require Time::HiRes;
		Time::HiRes::usleep(5000); # 5 milli-sec

		if ( $self->{master}->is_joinable ) {
			$self->{master}->join;
		}
	}

	# TaskManager does handle thread *killing*
}

sub DESTROY {
	shift->cleanup;
}





######################################################################
# Worker thread main loop

sub _worker_loop {
	my ($queue) = @_;
	@_ = (); # Hack to avoid "Scalars leaked"

	# warn threads->tid . " -- Hi, I'm a thread.";

	# Hold a pointer to the global application root
	require Padre::Wx::App;
	my $wx = Padre::Wx::App->new;

	while ( my $frozen = $queue->dequeue ) {

		# warn threads->tid . " -- got task.";

		# warn("THREAD TERMINATING"), return 1 if not ref($task) and $task eq 'STOP';
		return 1 if not ref($frozen) and $frozen eq 'STOP';

		require Padre::Task;
		my $task = Padre::Task->deserialize( \$frozen );
		$task->{__thread_id} = threads->tid;

		my $before = Wx::PlThreadEvent->new(
			-1,
			$TASK_START_EVENT,
			$task->{__thread_id} . ";" . ref($task),
		);
		Wx::PostEvent( $wx, $before );

		# RUN
		$task->run;

		# FREEZE THE PROCESS AND PASS IT BACK
		undef $frozen;
		$task->serialize( \$frozen );

		my $after = Wx::PlThreadEvent->new(
			-1,
			$TASK_DONE_EVENT,
			$frozen,
		);
		Wx::PostEvent( $wx, $after );

		# warn threads->tid . " -- done with task.";
	}
}

sub _slave_driver_loop {
	my ( $in, $out ) = @_;
	@_ = (); # Hack to avoid "Scalars leaked"

	while ( my $args = $in->dequeue ) { # args is frozen [$main, $queue]
		last if $args eq 'STOP';
		my $queue = Padre::SlaveDriver->new->task_queue;
		my $worker = threads->create( \&_worker_loop, $queue );
		$out->enqueue( $worker->tid );
	}

	return 1;
}

1;

=pod

=head1 TO DO

What if the computer can't keep up with the queued jobs? This needs
some consideration and probably, the C<schedule()> call needs to block once
the queue is I<"full">. However, it's not clear how this can work if the
Wx C<MainLoop> isn't reached for processing finish events.

Polling services I<aliveness> in a useful way, something a C<Wx::Taskmanager>
might like to display. Ability to selectively kill tasks/services

=head1 SEE ALSO

The base class of all I<"work units"> is L<Padre::Task>.

=head1 AUTHOR

Steffen Mueller C<smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
