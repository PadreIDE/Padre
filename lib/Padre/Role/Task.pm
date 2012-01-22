package Padre::Role::Task;

=pod

=head1 NAME

Padre::Role::Task - A role for objects that commission tasks

=head1 DESCRIPTION

This is a role that should be inherited from by objects in Padre's
permanent model that want to commision tasks to be run and have the
results fed back to them, if the answer is still relevant.

=head2 Task Revisions

Objects in Padre that commission tasks to run in the background can continue
processing and changing state during the queue'ing and/or execution of their
background tasks.

If the object state changes in such a way as to make the results of a background
task irrelevant, a mechanism is needed to ensure these background tasks are
aborted where possible, or their results thrown away when not.

B<Padre::Role::Task> provides the concept of "task revisions" to support this
functionality.

A task revision is an incrementing number for each owner that remains the same
as long as the results from any arbitrary launched task remains relevant for
the current state of the object.

When an object transitions a state boundary it will increment it's revision,
whether there are any running tasks or not.

When a task has completed the task manager will look up the owner (if it has
one) and check to see if the current revision of the owner object is the same
as when the task was scheduled. If so the Task Manager will call the
C<on_finish> handler passing it the task. If not, the completed task will be
silently discarded.

=head2 Sending messages to your tasks

The L<Padre::Task> API supports bidirection communication between tasks and
their owners.

However, when you commission a task via C<task_request> the task object is not
returned, leaving you without access to the task and thus without a method by
which to send messages to the child.

This is intentional, as there is no guarentee that your task will be launched
immediately and so sending messages immediately may be unsafe. The task may
need to be delayed until a new background worker can be spawned, or for longer
if the maximum background worker limit has been reached.

The solution is provided by the C<on_message> handler, which is passed the
parent task object as its first parameter.

Tasks which expect to be sent messages from their owner should send the owner
a greeting message as soon as they have started. Not only does this let the
parent know that work has commenced on their task, but it provides the task
object to the owner once there is certainty that any parent messages can be
dispatched to the child successfully.

In the following example, we assume a long running "service" style task that
will need to be interacted with over time.

  sub service_start {
      my $self = shift;
  
      $self->task_reset;
      $self->task_request(
          task       => 'My::Service',
          on_message => 'my_message',
          on_finish  => 'my_finish',
      );
  }
  
  sub my_message {
      my $self = shift;
      my $task = shift;
  
      # In this example our task sends an empty message to indicate "started"
      unless ( @_ ) {
          $self->{my_service} = $task;
          return;
      }
  
      # Handle other messages...
  }

=head1 METHODS

=cut

use 5.008005;
use strict;
use warnings;
use Scalar::Util   ();
use Padre::Current ();
use Padre::Logger;

our $VERSION    = '0.94';
our $COMPATIBLE = '0.91';

# Use a shared sequence for object revisioning greatly
# simplifies the indexing process.
my $SEQUENCE = 0;
my %INDEX    = ();





######################################################################
# Main Methods

=pod

=head2 task_owner

  Padre::Role::Task->task_owner( 1234 );

The C<task_owner> static method is a convenience method which takes an owner
id and will look up the owner object.

Returns the object if it still exists and has not changed it's task revision.

Returns C<undef> of the owner object no longer exists, or has changed its task
revision since the original owner id was issued.

=cut

sub task_owner {
	$INDEX{ $_[1] || 0 };
}

=pod

=head2 task_manager

The C<task_manager> method is a convenience for quick access to the Padre's
L<Padre::TaskManager> instance.

=cut

sub task_manager {
	TRACE( $_[0] ) if DEBUG;
	return $_[0]->can('current')
		? $_[0]->current->ide->task_manager
		: Padre::Current->ide->task_manager;
}

=pod

=head2 task_revision

The C<task_revision> accessor returns the current task revision for an object.

=cut

sub task_revision {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Set a revision if this is the first time
	unless ( defined $self->{task_revision} ) {
		$self->{task_revision} = ++$SEQUENCE;
	}

	# Optimisation hack: Only populate the index when
	# the revision is queried from the view.
	unless ( exists $INDEX{ $self->{task_revision} } ) {
		$INDEX{ $self->{task_revision} } = $self;
		Scalar::Util::weaken( $INDEX{ $self->{task_revision} } );
	}

	TRACE("Owner revision is $self->{task_revision}") if DEBUG;
	return $self->{task_revision};
}

=pod

=head2 task_reset

The C<task_reset> method is called when the state of an owner object
significantly changes, and outstanding tasks should be deleted or ignored.

It will change the task revision of the owner and request the task manager to
send a standard C<cancel> message to any currently executing background tasks,
allowing them to terminate elegantly (if they handle 

=cut

sub task_reset {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	if ( $self->{task_revision} ) {
		delete $INDEX{ $self->{task_revision} };
		$self->task_manager->cancel( $self->{task_revision} );
	}
	$self->{task_revision} = ++$SEQUENCE;
}

=pod

=head2 task_request

  $self->task_request(
      task       => 'Padre::Task::SomeTask',
      on_message => 'message_handler_method',
      on_finish  => 'finish_handler_method',
      my_param1  => 123,
      my_param2  => 'abc',
  );

The C<task_request> method is used to spawn a new background task for the
owner, loading the class and registering for callback messages in the process.

The C<task> parameter indicates the class of the task to be executed, which
must inherit from L<Padre::Task>. The class itself will be automatically loaded
if required.

The optional C<on_message> parameter should be the name of a method
(which must exist if provided) that will receive owner-targetted messages from
the background process.

The method will be passed the task object (as it exists after the C<prepare>
phase in the parent thread) as its first parameter, followed by any values
passed by the background task.

If no C<on_message> parameter is provided the default method null
C<task_message> will be called.

The optional C<on_finish> parameter should be the name of a method
(which must exist if provided) that will receive the task object back from
the background worker once the task has completed, complete with any state
saved in the task during its background execution.

It is passed a single parameter, which is the L<Padre::Task> object.

If no C<on_finish> parameter is provided the default method null
C<task_finish> will be called.

Any other parameters are passed through the constructor method of the task.

=cut

sub task_request {
	TRACE( $_[0] ) if DEBUG;
	my $self  = shift;
	my %param = @_;

	# Check and load the task
	# Support a convenience shortcut where a false value
	# for task means don't run a task at all.
	my $name = delete $param{task} or return;
	my $driver = Params::Util::_DRIVER( $name, 'Padre::Task' );
	die "Invalid task class '$name'" unless $driver;

	# Create and start the task with ourself as the owner
	TRACE("Creating and scheduling task $driver") if DEBUG;
	my $task = $driver->new(
		owner => $self->task_revision,
		%param,
	);

	# Check the run event handler
	my $on_run = $task->on_run;
	if ( $on_run and not $self->can($on_run) ) {
		die "The on_run handler '$on_run' is not implemented";
	}

	# Check the status event handler
	my $on_status = $task->on_status;
	if ( $on_status and not $self->can($on_status) ) {
		die "The on_status handler '$on_status' is not implemented";
	}

	# Check the message event handler
	my $on_message = $task->on_message;
	if ( $on_message and not $self->can($on_message) ) {
		die "The on_message handler '$on_message' is not implemented";
	}

	# Check the finish event handler
	my $on_finish = $task->on_message;
	if ( $on_finish and not $self->can($on_finish) ) {
		die "The on_message handler '$on_finish' is not implemented";
	}

	# Send the task for execution
	$task->schedule;
}

=pod

=head2 task_finish

The C<task_finish> method is the default handler method for completed tasks,
and will be called for any C<task_request> where no specific C<on_finish>
handler was provided.

If your object issues only one task, or if you would prefer a single common
finish handler for all your different tasks, you should override this method
instead of explicitly defining an C<on_finish> handler for every task.

The default implementation ensures that every task has an appropriate finish
handler by throwing an exception with a message indicating the owner and task
class for which no finish handler could be found.

=cut

sub task_finish {
	my $class = ref( $_[0] ) || $_[0];
	my $task  = ref( $_[1] ) || $_[1];
	die "Unhandled task_finish for $class (recieved $task)";
}

=pod

=head2 task_message

The C<task_message> method is the default handler method for completed tasks,
and will be called for any C<task_request> where no specific C<on_message>
handler was provided.

If your object issues only one task, or if you would prefer a single common
message handler for all your different tasks, you should override this method
instead of explicitly defining an C<on_finish> handler for every task.

If none of your tasks will send messages back to their owner, you do not need
to define this method.

The default implementation ensures that every task has an appropriate finish
handler by throwing an exception with a message indicating the owner and task
class for which no finish handler could be found.

=cut

sub task_message {
	my $class = ref( $_[0] ) || $_[0];
	my $task  = ref( $_[1] ) || $_[1];
	die "Unhandled task_message for $class (recieved $task message $_[2]->[0])";
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
