package Padre::Task;

=pod

=head1 NAME

Padre::Task - Padre Task API 3.0

=head1 SYNOPSIS

  # Fire a task that will communicate back to an owner object
  My::Task->new( 
      owner      => $padre_role_task_object,
      on_run     => 'owner_run_method',
      on_status  => 'owner_status_method',
      on_message => 'owner_message_method',
      on_finish  => 'owner_finish_method',
      my_param1  => 123,
      my_param2  => 'abc',
  )->schedule;
  
  
  
  package My::Task;
  
  sub new {
      my $class = shift;
      my $self  = $class->SUPER::new(@_);
  
      # Check params and validate the task
  
      return $self;
  }
  
  sub prepare {
      my $self = shift;
  
      # Run after scheduling immediately before serialised to a worker

      return 0 if $self->my_last_second_abort_check;
      return 1; # Continue and run
  }
  
  sub run {
      my $self = shift;
  
      # Called in child, do the work here
  
      return 1;
  }
  
  sub finish {
      my $self = shift;
  
      # Called in parent after successful completion
  
      return 1;
  }
  
  1;

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

=head3 1. Construction

The creation of a task is always done completely independantly of its
execution. Typically this is done via the C<new> method, or something
that calls it.

This separate construction step allows validation of parameters in
advance, as well as allowing bulk task pre-generation and advanced task
management functionality such as prioritisation, queueing, throttling and
load-balancing of tasks.

=head3 2. Preparation

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

=head3 3. Execution

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

=head3 4. Cleanup

When the execution phase of the task is completed, the task object will be
serialised for transport back up to the parent thread.

On arrival, the instance of the task in the parent will be gutted and its
contents replaced with the contents of the version arriving from the child
thread.

Once this is complete, the task object will fire a "finish" handler allowing
it to take action in the parent thread based on the work done in the child.

This can include having the task contact any "owner" object that had
commissioned the task in the first place.

=head1 METHODS

=cut

use 5.008005;
use strict;
use warnings;
use Storable          ();
use Scalar::Util      ();
use Params::Util      ();
use Padre::Current    ();
use Padre::Role::Task ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.91';

=pod

=head2 new

  My::Task->new( 
      owner      => $padre_role_task_object,
      on_run     => 'owner_run_method',
      on_status  => 'owner_status_method',
      on_message => 'owner_message_method',
      on_finish  => 'owner_finish_method',
      my_param1  => 123,
      my_param2  => 'abc',
  );

The C<new> method creates a new "task", a self-contained object that represents
a unit of work to be done in the background (although not required to be done
in the background).

In addition to defining a set of method for you to provide as the task
implementer, the base class also provides implements a "task ownership" system
in the base class that you may use for nearly no cost in terms of code.

This task owner system will consume three parameters.

The optional C<owner> parameter should be an object that inherits from the role
L<Padre::Role::Task>. Message and finish events for this task will be forwarded
on to handlers on the owner, if they are defined.

The optional C<on_run> parameter should be the name of a method that can be
called on the owner object, to be called once the task has started running and
control of the worker message queue has been handed over to the task.

The optional C<on_message> parameter should be the name of a method that can be
called on the owner object, to be called when a message arrives from the child
object during its execution.

The required (if C<owner> was provided) C<on_finish> parameter should be the
name of a method that can be called on the owner object, to be called when the
task has completed and returns to the parent from the child object.

When implementing your own task, you should always call the C<SUPER::new>
method first, to ensure that integration with the task owner system is done.

You can then check any other parameters, capture additional information from
the IDE, and validate that the task is correctly requested and should go ahead.

The creation of a task object does NOT imply that it will be executed, merely
that the require for work to be done is validly formed. A task object may never
execute, or may only execute significantly later than it was created.

Anything that the task needs to do once it is certain that the task will be
run should be done in the C<prepare> method (see below).

Returns a new task object if the request is valid, or throws an exception if
the request is invalid.

=cut

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Check parameters relevant to our optional owner
	if ( exists $self->{owner} ) {
		if ( exists $self->{on_run} ) {
			unless ( Params::Util::_IDENTIFIER( $self->{on_run} ) ) {
				die "Task 'on_run' method be a method name";
			}
		}
		if ( exists $self->{on_status} ) {
			unless ( Params::Util::_IDENTIFIER( $self->{on_status} ) ) {
				die "Task 'on_status' must be a method name";
			}
		}
		if ( exists $self->{on_message} ) {
			unless ( Params::Util::_IDENTIFIER( $self->{on_message} ) ) {
				die "Task 'on_message' must be a method name";
			}
		}
		if ( exists $self->{on_finish} ) {
			unless ( Params::Util::_IDENTIFIER( $self->{on_finish} ) ) {
				die "Task 'on_finish' must be a method name";
			}
		}
	}

	return $self;
}

=pod

=head2 on_run

The C<on_run> accessor returns the name of the owner's C<run> notification
handler method, if one was defined.

=cut

sub on_run {
	$_[0]->{on_run};
}

=pod

=head2 on_status

The C<on_status> accessor returns the name of the owner's status handler
method, if one was defined.

=cut

sub on_status {
	$_[0]->{on_status};
}

=pod

=head2 on_message

The C<on_message> accessor returns the name of the owner's message handler
method, if one was defined.

=cut

sub on_message {
	$_[0]->{on_message};
}

=pod

=head2 on_finish

The C<on_finish> accessor returns the name of the owner's finish handler
method, if one was defined.

=cut

sub on_finish {
	$_[0]->{on_finish} || 'task_finish';
}





######################################################################
# Serialization - Based on Process::Serializable and Process::Storable

=pod

=head2 as_string

The C<as_string> method is used to serialise the task into a string for
transmission between the parent and the child (in both directions).

By default your task will be serialised using L<Storable>'s C<nfreeze> method,
which is suitable for transmission between threads or processes running the
same instance of Perl with the same module search path.

This should be sufficient in most situations.

=cut

sub as_string {
	Storable::nfreeze( $_[0] );
}

=pod

=head2 from_string

The C<from_string> method is used to deserialise the task from a string after
transmission between the parent and the child (in both directions).

By default your task will be deserialised using L<Storable>'s C<thaw> method,
which is suitable for transmission between threads or processes running the
same instance of Perl with the same module search path.

This should be sufficient in most situations.

=cut

sub from_string {
	my $class = shift;
	my $self  = Storable::thaw( $_[0] );
	unless ( Scalar::Util::blessed($self) eq $class ) {

		# Because this is an internal API we can be brutally
		# unforgiving if we aren't use the right way.
		die("Task unexpectedly did not deserialize as a $class");
	}
	return $self;
}





######################################################################
# Task API - Based on Process.pm

=pod

=head2 locks

The C<locks> method returns a list of locks that the task needs to reserve in
order to execute safely.

The meaning, usage, and available quantity of the required locks are tracked by
the task manager. Enforcement of resource limits may be strict, or may only
serve as hints to the scheduler.

Returns a list of strings, or the null list if the task is light with trivial
or no resource consumption.

=cut

sub locks {
	return ();
}

=pod

=head2 schedule

  $task->schedule;

The C<schedule> method is used to trigger the sending of the task to a worker
for processing at whatever time the Task Manager deems it appropriate.

This could be immediately, with the task sent before the call returns, or it
may be delayed indefinately or never run at all.

Returns true if the task was dispatched immediately.

Returns false if the task was queued for later dispatch.

=cut

sub schedule {
	Padre::Current->ide->task_manager->schedule(@_);
}

=pod

=head2 prepare

The optional C<prepare> method will be called by the task manager on your task
object while still in the parent thread, immediately before being serialised to
pass to the worker thread.

This method should be used to compensate for the potential time difference
between when C<new> is oridinally called and when the task will actually be run.

For example, a GUI element may indicate the need to run a background task on
the visible document but does not care that it is the literally "current"
document at the time the task was spawned.

By capturing the contents of the current document during C<prepare> rather than
C<new> the task object is able to apply the task to the most up to date
information at the time we are able to do the work, rather than at the time
we know we need to do the work.

The C<prepare> method can take a relatively heavy parameter such as a
reference to a Wx element, and flatten it to the widget ID or contents of the
widget instead.

The C<prepare> method also gives your task object a chance to determine whether
or not it is still necessary. In some situations the delay between C<new> and
C<prepare> may be long enough that the task is no longer relevant, and so by
the use of C<prepare> you can indicate execution should be aborted.

Returns true if the task is stil valid, and so the task should be executed.

Returns false if the task is no longer valid, and the task should be aborted.

=cut

sub prepare {
	return 1;
}

=pod

=head2 run

The C<run> method is called on the object in the worker thread immediately
after deserialisation. It is where the actual computations and work for the
task occurs.

In many situations the implementation of run is simple and procedural, doing
work based on input parameters stored on the object, blocking if necessary,
and storing the results of the computation on the object for transmission
back to the parent thread.

In more complex scenarios, you may wish to do a series of tasks or a recursive
set of tasks in a loop with a check on the C<cancelled> method periodically to
allow the aborting of the task if requested by the parent.

In even more advanced situations, you may embed and launch an entire event loop
such as L<POE> or L<AnyEvent> inside the C<run> method so that long running or
complex functionality can be run in the background.

Once inside of C<run> your task is in complete control and the task manager
cannot interupt the execution of your code short of killing the thread
entirely. The standard C<cancelled> method to check for a request from the
parent to abort your task is cooperative and entirely voluntary.

Returns true if the computation was completed successfully.

Returns false if the computation was not completed successfully, and so the
parent should not run any post-task logic.

=cut

sub run {
	return 1;
}

=pod

=head2 finish

The C<finish> method is called on the object in the parent thread once it has
been passed back up to the parent, if C<run> completed successfully.

It is responsible for cleaning up the task and taking any actions based on the
result of the computation.

If your task is fire-and-forget or void and you don't care about when the
task completes, you do not need to implement this method.

The default implementation of C<finish> implements redirection to the
C<on_finish> handler of the task owner object, if one has been defined.

=cut

sub finish {
	return 1;
}

=pod

=head2 is_parent

The C<is_parent> method returns true if the task object is in the parent thread,
or false if it is in the child thread.

=cut

sub is_parent {
	not defined $_[0]->{handle};
}

=pod

=head2 is_child

The C<is_child> method returns true if the task object is in the child thread,
or false if it is in the parent thread.

=cut

sub is_child {
	defined $_[0]->{handle};
}





######################################################################
# Birectional Communication

=pod

=head2 cancelled

  sub run {
      my $self = shift;
  
      # Abort a long task if we are no longer wanted
      foreach my $thing ( @{$self->{lots_of_stuff}} ) {
          return if $self->cancelled;
  
          # Do something expensive
      }
  
      return 1;
  }

The C<cancelled> method should be called in the child worker, and allows the
task to be cooperatively aborted before it has completed.

The abort mechanism is cooperative. Tasks that do not periodically check the
C<cancelled> method will continue until they are complete regardless of the
desires of the task manager.

=cut

sub cancelled {
	return unless defined $_[0]->{handle};
	return shift->{handle}->cancelled;
}

# Fetch the next message from our inbox
sub child_inbox {
	return undef unless defined $_[0]->{handle};
	return shift->{handle}->inbox;
}

# Block until we are cancelled or there is a message from our parent
sub child_wait {
	return unless defined $_[0]->{handle};
	return shift->{handle}->wait;
}

sub tell_parent {
	return unless defined $_[0]->{handle};
	return shift->{handle}->tell_parent(@_);
}

sub tell_child {
	return unless defined $_[0]->{handle};
	return shift->{handle}->tell_child(@_);
}

sub tell_owner {
	return unless defined $_[0]->{handle};
	return shift->{handle}->tell_owner(@_);
}

=pod

=head2 tell_status

  # Indicate we are waiting, but only while we are waiting
  $task->tell_status('Waiting...');
  sleep 5
  $task->tell_status;

The C<tell_status> method allows a task to trickle informative status messages
up to the parent thread. These messages serve a dual purpose.

Firstly, the messages will (or at least I<may>) be displayed to the user to
indicate progress through a long asynchronous background task. For example, a
filesystem search task might send a status message for each directory that it
examines, so that the user can monitor the task speed and level of completion.

Secondly, the regular flow of messages from the task indicates to the
L<Padre::TaskManager> that the task is running correctly, making progress
through its assigned workload, and has probably not crashed or hung.

While the task manager does not currently kill hanging threads, it will almost
certainly do so in the future. And so it may even be worth sending a periodic
null status message every few seconds just to assure the task manager that your
long-running task is still alive.

=cut

sub tell_status {
	return unless defined $_[0]->{handle};
	return shift->{handle}->tell_status(@_);
}

1;

=pod

=head1 SEE ALSO

L<Padre>, L<Process>

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
