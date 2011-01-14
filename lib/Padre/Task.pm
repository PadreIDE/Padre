package Padre::Task;

=pod

=head1 NAME

Padre::Task - Padre Task API 2.0

=head1 DESCRIPTION

The Padre Task API implements support for background and parallel
execution of code in the L<Padre> IDE, and is based on the CPAN
L<Process> API.

A B<Task Class> is a class that completely encapsulates a single unit of
work, describing not only the work to be done, but also how the unit of
work is created, how is serialised for transport, and any initialisation
or cleanup work needs to be done.

A B<Task> is a single self-contained unit of work, and is implemented as
a single instance of a particular Task Class.

=head2 The lifecycle of a Task object

From the perspective of a task author, the execution of a task will occur
in four distinct phases.

=head3 Construction

The creation of a task is always done completely independantly of its
execution. Typically this is done via the C<new> method, or something
that calls it.

This separate construction step allows validation of parameters in
advance, as well as allowing bulk task pre-generation and advanced task
management functionality such as prioritisation, queueing, throttling and
load-balancing of tasks.

=head3 Preparation

Once a task has been constructed, an arbitrarily long time may pass before
the code is actually run (if it is ever run at all).

If the actual execution of the task will result in certain work being done
in the parent thread, this work cannot be done in the constructor. And once
created as an object, no futher task code will be called until the task is
ready for execution.

To give the author a chance to allow for any problems that may occur as a
result of this delay, the Task API provides a preparation phase for the
task via the C<prepare> method.

This preparation code is run in the parent thread once the task has been
prioritised, has a worker allocated to it, and has been encapsulated in its
L<Padre::TaskHandle>, but before the object is serialised for transport
into the thread.

A task can use this preparation phase to detach from non-serialisable
resources in the object such as database handles, to copy any interesting
parent state late rather than early, or decide on a last-second self-abort.

Once the preparation phase is completed the task will be serialised,
transported into assigned worker thread and then executed B<immediately>.

Because it will execute in the parent thead, the rest of the Padre instance
is available for use if needed, but the preparation code should run quickly
and must not block.

=head3 Execution

The main phase of the task is where the CPU-intensive or blocking code can
be safely run. It is run inside a worker thread in the background, without
impacting on the performance of the parent thread.

However, the task execution phase must be entirely self-contained.

The worker threads not only do not have access to the Padre IDE variable
structure, but most Padre classes (including heavily used modules such as
L<Padre::Current>) will not be loaded at all in the worker thread.

Any output that needs to be transported back to the parent should be stored
in the object somewhere. When the cleanup phase is run, these values will
be available automatically in the parent.

TO BE COMPLETED

=cut

use 5.008005;
use strict;
use warnings;
use Storable          ();
use Scalar::Util      ();
use Params::Util      ();
use Padre::Current    ();
use Padre::Role::Task ();

our $VERSION    = '0.78';
our $COMPATIBLE = '0.65';

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	if ( exists $self->{owner} ) {

		# Check parameters relevant to our optional owner
		if ( exists $self->{on_message} ) {
			my $method = Params::Util::_IDENTIFIER( $self->{on_message} );
			unless ($method) {
				die "Task 'on_message' must be a method name";
			}
			unless ( $self->{owner}->can($method) ) {
				die "The on_message handler '$method' is not implemented";
			}
		}
		if ( exists $self->{on_finish} ) {
			unless ( Params::Util::_IDENTIFIER( $self->{on_finish} ) ) {
				die "Task 'on_finish' must be a method name";
			}
		}
		my $method = $self->on_finish;
		unless ( $self->{owner}->can($method) ) {
			die "Task on_finish '$method' is not implemented";
		}

		# Save the numeric identifier of our owner
		$self->{owner} = $self->{owner}->task_revision;
	}

	return $self;
}

sub handle {
	$_[0]->{handle};
}

sub running {
	defined $_[0]->{handle};
}

sub owner {
	Padre::Role::Task->task_owner( $_[0]->{owner} );
}

sub on_message {
	$_[0]->{on_message};
}

sub on_finish {
	$_[0]->{on_finish} || 'task_finish';
}





######################################################################
# Serialization - Based on Process::Serializable and Process::Storable

# my $string = $task->as_string;
sub as_string {
	Storable::nfreeze( $_[0] );
}

# my $task = Class::Name->from_string($string);
sub from_string {
	my $class = shift;
	my $self  = Storable::thaw( $_[0] );
	unless ( Scalar::Util::blessed($self) eq $class ) {

		# Because this is an internal API we can be brutally
		# unforgiving is we aren't use the right way.
		die("Task unexpectedly did not deserialize as a $class");
	}
	return $self;
}





######################################################################
# Task API - Based on Process.pm

# Send the task to the task manager to be executed
sub schedule {
	Padre::Current->ide->task_manager->schedule(@_);
}

# Called in the parent thread immediately before being passed
# to the worker thread. This method should compensate for
# potential time difference between when C<new> is original
# called, and when the Task is actually run.
# Returns true if the task should continue and be run.
# Returns false if the task is irrelevant and should be aborted.
sub prepare {
	return 1;
}

# Called in the worker thread, and should continue the main body
# of code that needs to run in the background.
# Variables saved to the object in the C<prepare> method will be
# available in the C<run> method.
sub run {
	my $self = shift;

	# If we have an owner, and it has moved on to a different state
	# while we have been waiting to be executed abort the run.
	if ( $self->{owner} ) {
		$self->owner or return 0;
	}

	return 1;
}

# Called in the parent thread immediately after the task has
# completed and been passed back to the parent.
# Variables saved to the object in the C<run> method will be
# available in the C<finish> method.
# The object may be destroyed at any time after this method
# has been completed.
sub finish {
	my $self = shift;

	if ( $self->{owner} ) {
		my $owner = $self->owner or return;
		my $method = $self->on_finish;
		$owner->$method($self);
	}

	return 1;
}





######################################################################
# Birectional Communication

sub cancel {
	return !!( defined $_[0]->{handle} and $_[0]->{handle}->cancel );
}

sub dequeue {
	return unless defined $_[0]->{handle};
	return $_[0]->{handle}->dequeue;
}

sub dequeue_nb {
	return unless defined $_[0]->{handle};
	return $_[0]->{handle}->dequeue_nb;
}

1;

=pod

=head1 SEE ALSO

L<Padre>, L<Process>

=head1 COPYRIGHT

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
