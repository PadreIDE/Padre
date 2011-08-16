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

our $VERSION  = '0.90';
our $SEQUENCE = 0;





######################################################################
# Constructor and Accessors

sub new {
	TRACE( $_[0] ) if DEBUG;
	return bless {
		hid  => ++$SEQUENCE,
		task => $_[1],
		},
		$_[0];
}

sub hid {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{hid};
}

sub task {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{task};
}

sub child {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{child};
}

sub class {

	# TRACE( $_[0] ) if DEBUG;
	Scalar::Util::blessed( $_[0]->{task} );
}

sub worker {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	$self->{worker} = shift if @_;
	$self->{worker};
}

sub queue {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{queue};
}

sub inbox {

	# TRACE( $_[0] ) if DEBUG;
	$_[0]->{inbox};
}

sub start_time {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	$self->{start_time} = $self->{idle_time} = shift if @_;
	$self->{start_time};
}

sub idle_time {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	$self->{idle_time} = shift if @_;
	$self->{idle_time};
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
# Biderectional Communication

# Parent: Push into worker's thread queue
# Child:  Serialize and pass-through to the Wx signal dispatch
sub message {
	TRACE( $_[0] ) if DEBUG;
	if ( $_[0]->child ) {
		Padre::Wx::Role::Conduit->signal( Storable::freeze( [ shift->hid, @_ ] ) );
	} else {
		shift->worker->send( 'message', @_ );
	}
	return 1;
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
			require Padre::Current;
			Padre::Current->main->status(@_);
			return;
		}

		# Special case for routing messages to the owner of a task
		# rather than to the task itself.
		if ( $method eq 'OWNER' ) {
			my $owner  = $task->owner      or return;
			my $method = $task->on_message or return;
			$owner->$method( $task, @_ );
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

	# Execute the finish method in the updated Task object
	local $@;
	eval { $self->{task}->finish; };
	if ($@) {

		# A method in the main thread blew up.
		# Beyond catching it and preventing it killing
		# Padre entirely, I'm not sure what else we can
		# really do about it at this point.
		return;
	}

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
	$self->{inbox} = [];

	# Create a circular reference back from the task
	# HACK: This is pretty damned evil, find a better way
	$task->{handle} = $self;

	# Call the task's run method
	eval { $task->run; };

	# Clean up the temps
	delete $task->{handle};
	delete $self->{inbox};

	# Save the exception if thrown
	if ($@) {
		TRACE("Exception in task during 'run': $@") if DEBUG;
		$self->{exception} = $@;
		return !1;
	}

	return 1;
}

# Signal the task has started
sub started {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->message('STARTED');
}

# Signal the task has stopped
sub stopped {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->message( 'STOPPED', $_[0]->{task} );
}

# Set the parent status bar to some string (or blank if null)
sub status {
	my $self = shift;
	my $string = @_ ? shift : '';
	$self->message( STATUS => $string );
}

# Has this task been cancelled by the parent?
sub cancel {
	my $self = shift;

	# Have we been cancelled but forgot to check till now?
	return 1 if $self->{cancel};

	# Without an inbox or queue we aren't running properly,
	# so the question of whether we have been cancelled is moot.
	my $inbox = $self->{inbox} or return;
	my $queue = $self->{queue} or return;

	# Fetch any new messages from the queue, scanning for cancel
	foreach my $message ( $queue->dequeue_nb ) {
		if ( $message->[0] eq 'cancel' ) {
			$self->{cancel} = 1;
			next;
		}
		push @$inbox, $message;
	}

	return !!$self->{cancel};
}

# Blocking check for inbound messages from the parent
sub dequeue {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Pull from the inbox first
	my $inbox = $self->inbox or return 0;
	if (@$inbox) {
		return shift @$inbox;
	}

	# Pull off the queue
	my $queue = $self->queue or return 0;
	foreach my $message ( $queue->dequeue ) {
		if ( $message->[0] eq 'cancel' ) {
			$self->{cancel} = 1;
			next;
		}
	}

	# Check the message for valid structure
	my $message = shift @$inbox or return 0;
	unless ( Params::Util::_ARRAY($message) ) {
		TRACE('Non-ARRAY message received by a worker thread') if DEBUG;
		return 0;
	}
	unless ( Params::Util::_IDENTIFIER( $message->[0] ) ) {
		TRACE('Non-method message received by worker thread') if DEBUG;
		return 0;
	}

	return $message;
}

# Non-blocking check for inbound messages from our parent
sub dequeue_nb {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Pull from the inbox first
	my $inbox = $self->inbox or return 0;
	if (@$inbox) {
		return shift @$inbox;
	}

	# Pull off the queue, non-blocking
	my $queue = $self->queue or return 0;
	foreach my $message ( $queue->dequeue_nb ) {
		if ( $message->[0] eq 'cancel' ) {
			$self->{cancel} = 1;
			next;
		}
	}

	# Check the message for valid structure
	my $message = shift @$inbox or return 0;
	unless ( Params::Util::_ARRAY($message) ) {
		TRACE('Non-ARRAY message received by a worker thread') if DEBUG;
		return 0;
	}
	unless ( Params::Util::_IDENTIFIER( $message->[0] ) ) {
		TRACE('Non-method message received by worker thread') if DEBUG;
		return 0;
	}

	return $message;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
