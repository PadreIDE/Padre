package Padre::TaskHandle;

use 5.008005;
use strict;
use warnings;
use threads;
use threads::shared;
use Scalar::Util             ();
use Params::Util             ();
use Storable                 ();
use Padre::Wx::Role::Conduit ();
use Padre::Logger;

our $VERSION  = '0.94';
our $SEQUENCE = 0;





######################################################################
# Constructor and Accessors

sub new {
	TRACE( $_[0] ) if DEBUG;
	bless {
		hid  => ++$SEQUENCE,
		task => $_[1],
		},
		$_[0];
}

sub hid {
	$_[0]->{hid};
}

sub task {
	$_[0]->{task};
}

sub child {
	$_[0]->{child};
}

sub class {
	Scalar::Util::blessed( $_[0]->{task} );
}

sub has_owner {
	!!$_[0]->{task}->{owner};
}

sub owner {
	require Padre::Role::Task;
	Padre::Role::Task->task_owner( $_[0]->{task}->{owner} );
}

sub worker {
	my $self = shift;
	$self->{worker} = shift if @_;
	$self->{worker};
}

sub queue {
	$_[0]->{queue};
}

sub start_time {
	my $self = shift;
	$self->{start_time} = $self->{idle_time} = shift if @_;
	$self->{start_time};
}

sub idle_time {
	my $self = shift;
	$self->{idle_time} = shift if @_;
	$self->{idle_time};
}





######################################################################
# Setup and teardown

# Called in the child thread to set the task and handle up for processing.
sub start {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	$self->{child} = 1;
	$self->{queue} = shift;
	$self->signal('STARTED');
}

# Signal the task has stopped
sub stop {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	$self->{child} = undef;
	$self->{queue} = undef;
	$self->signal( 'STOPPED' => $self->{task} );
}





######################################################################
# Serialisation

sub as_array {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = $self->task;
	return [
		$self->hid,
		Scalar::Util::blessed($task),
		$task->as_string,
	];
}

sub from_array {
	TRACE( $_[0] ) if DEBUG;
	my $class = shift;
	my $array = shift;

	# Load the task class first so we can deserialize
	TRACE("$class: Loading $array->[1]") if DEBUG;
	eval "require $array->[1];";
	die $@ if $@;

	return bless {
		hid  => $array->[0] + 0,
		task => $array->[1]->from_string( $array->[2] ),
	}, $class;
}





######################################################################
# Parent-Only Methods

sub prepare {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = $self->{task};

	unless ( defined $task ) {
		TRACE("Exception: task not defined") if DEBUG;
		return !1;
	}

	my $rv = eval { $task->prepare; };
	if ($@) {
		TRACE("Exception in task during 'prepare': $@") if DEBUG;
		return !1;
	}
	return !!$rv;
}

sub on_started {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = $self->{task};

	# Does the task have an owner and can we call it
	my $owner  = $self->owner  or return;
	my $method = $task->on_run or return;
	$owner->$method( $task => @_ );
	return;
}

sub on_message {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $method = shift;
	my $task   = $self->{task};

	unless ( $self->child ) {

		# Special case for printing a simple message to the main window
		# status bar, without needing to pollute the task classes.
		if ( $method eq 'STATUS' ) {
			return $self->on_status(@_);
		}

		# Special case for routing messages to the owner of a task
		# rather than to the task itself.
		if ( $method eq 'OWNER' ) {
			require Padre::Role::Task;
			my $owner  = $self->owner      or return;
			my $method = $task->on_message or return;
			$owner->$method( $task => @_ );
			return;
		}
	}

	# Does the method exist
	unless ( $self->{task}->can($method) ) {

		# A method name provided directly by the Task
		# doesn't exist in the Task. Naughty Task!!!
		# Lacking anything more sane to do, squelch it.
		return;
	}

	# Pass the call down to the task and protect it from itself
	local $@;
	eval { $self->{task}->$method(@_); };
	if ($@) {

		# A method in the main thread blew up.
		# Beyond catching it and preventing it killing
		# Padre entirely, I'm not sure what else we can
		# really do about it at this point.
		return;
	}

	return;
}

sub on_status {
	TRACE( $_[1] ) if DEBUG;
	my $self = shift;

	# If we don't have an owner, use the general status bar
	unless ( $self->has_owner ) {
		require Padre::Current;
		Padre::Current->main->status(@_);
		return;
	}

	# If we have an owner that is within the main window show normally
	my $owner = $self->owner or return;
	my $method = $self->{task}->on_status;
	return $owner->$method(@_) if $method;

	# Pass status messages up to the main window status if possible
	if ( $owner->isa('Padre::Wx::Role::Main') ) {
		$owner->main->status(@_);
		return;
	}

	# Nothing else to do
	return;
}

sub on_stopped {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# The first parameter is the updated Task object.
	# Replace all content in the stored version with that from the
	# event-provided version.
	my $new  = shift;
	my $task = $self->{task};
	%$task = %$new;
	%$new  = ();

	# Execute the finish method in the updated Task object first, before
	# the task owner is passed to the task owner (if any)
	$self->finish;

	# If the task has an owner it will get the finish method instead.
	my $owner = $self->owner or return;
	my $method = $self->{task}->on_finish;
	local $@;
	eval { $owner->$method( $self->{task} ); };

	return;
}

sub finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = $self->{task};
	my $rv   = eval { $task->finish; };
	if ($@) {
		TRACE("Exception in task during 'finish': $@") if DEBUG;
		return !1;
	}
	return !!$rv;
}





######################################################################
# Worker-Only Methods

sub run {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = $self->task;

	# Create the inbox for the handle
	local $self->{inbox} = [];

	# Create a circular reference back from the task
	# HACK: This is pretty damned evil, find a better way
	local $task->{handle} = $self;

	# Call the task's run method
	eval { $task->run; };
	if ($@) {

		# Save the exception
		TRACE("Exception in task during 'run': $@") if DEBUG;
		$self->{exception} = $@;
		return !1;
	}

	return 1;
}

# Poll the inbound queue and process them
sub poll {
	my $self  = shift;
	my $inbox = $self->{inbox} or return;
	my $queue = $self->{queue} or return;

	# Fetch from the queue until we run out of messages or get a cancel
	while ( my $item = $queue->dequeue1_nb ) {

		# Handle a valid parent -> task message
		if ( $item->[0] eq 'message' ) {
			my $message = Storable::thaw( $item->[1] );
			push @$inbox, $message;
			next;
		}

		# Handle aborting the task
		if ( $item->[0] eq 'cancel' ) {
			$self->{cancelled} = 1;
			delete $self->{queue};
			next;
		}

		die "Unknown or unexpected message type '$item->[0]'";
	}

	return;
}

# Block until we have an inbox message or have been cancelled
sub wait {
	my $self  = shift;
	my $inbox = $self->{inbox} or return;
	my $queue = $self->{queue} or return;

	# If something is in our inbox we don't need to wait
	return if @$inbox;

	# Fetch the next message from the queue, blocking if needed
	my $item = $queue->dequeue1;

	# Handle a valid parent -> task message
	if ( $item->[0] eq 'message' ) {
		my $message = Storable::thaw( $item->[1] );
		push @$inbox, $message;
		return;
	}

	# Handle aborting the task
	if ( $item->[0] eq 'cancel' ) {
		$self->{cancelled} = 1;
		delete $self->{queue};
		return;
	}

	die "Unknown or unexpected message type '$item->[0]'";
}

sub cancel {
	$_[0]->{cancelled} = 1;
}

# Has this task been cancelled by the parent?
sub cancelled {
	my $self = shift;

	# Shortcut if we can to avoid queue locking
	return 1 if $self->{cancelled};

	# Poll for new input
	$self->poll;

	# Check again now we have polled for new messages
	return !!$self->{cancelled};
}

# Fetch the next message from our inbox
sub inbox {
	my $self = shift;
	my $inbox = $self->{inbox} or return undef;

	# Shortcut if we can to avoid queue locking
	return shift @$inbox if @$inbox;

	# Poll for new messages
	$self->poll;

	# Check again now we have polled for new messages
	return shift @$inbox;
}





######################################################################
# Bidirectional Communication

sub signal {
	TRACE( $_[0] ) if DEBUG;
	Padre::Wx::Role::Conduit->signal( Storable::freeze( [ shift->hid => @_ ] ) );
}

sub tell_parent {
	TRACE( $_[0] ) if DEBUG;
	shift->signal( PARENT => @_ );
}

sub tell_child {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	if ( $self->child ) {

		# Add the message directly to the inbox
		my $inbox = $self->{inbox} or next;
		push @$inbox, [@_];
	} else {
		$self->worker->send_message(@_);
	}

	return 1;
}

sub tell_owner {
	TRACE( $_[0] ) if DEBUG;
	shift->signal( OWNER => @_ );
}

sub tell_status {
	TRACE( $_[0] ) if DEBUG;
	shift->signal( STATUS => @_ ? @_ : '' );
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
