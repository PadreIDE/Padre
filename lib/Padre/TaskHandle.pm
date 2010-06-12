package Padre::TaskHandle;

use 5.008005;
use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Queue 2.11;
use Scalar::Util             ();
use Storable                 ();
use Padre::Wx::Role::Conduit ();
use Padre::Logger;

our $VERSION  = '0.59';
our $SEQUENCE = 0;





######################################################################
# Constructor and Accessors

sub new {
	TRACE($_[0]) if DEBUG;
	bless {
		hid  => ++$SEQUENCE,
		task => $_[1],
	}, $_[0];
}

sub hid {
	TRACE($_[0]) if DEBUG;
	$_[0]->{hid};
}

sub task {
	TRACE($_[0]) if DEBUG;
	$_[0]->{task};
}





######################################################################
# Parent Methods

sub prepare {
	TRACE($_[0]) if DEBUG;
	my $self = shift;
	my $task = $self->{task};
	my $rv   = eval {
		$task->prepare;
	};
	if ( $@ ) {
		TRACE("Exception in task during 'prepare': $@") if DEBUG;
		return ! 1;
	}
	return !! $rv;
}

sub finish {
	TRACE($_[0]) if DEBUG;
	my $self = shift;
	my $task = $self->{task};
	my $rv   = eval {
		$task->finish;
	};
	if ( $@ ) {
		TRACE("Exception in task during 'finish': $@") if DEBUG;
		return ! 1;
	}
	return !! $rv;
}





######################################################################
# Worker Methods

sub run {
	TRACE($_[0]) if DEBUG;
	my $self = shift;
	my $task = $self->task;

	# Create a circular reference back from the task
	$task->{handle} = $self;

	# Call the task's run method
	eval {
		$task->run();
	};

	# Clean up the circular
	delete $task->{handle};

	# Save the exception if thrown
	if ( $@ ) {
		TRACE("Exception in task during 'run': $@") if DEBUG;
		$self->{exception} = $@;
		return ! 1;
	}

	return 1;
}





######################################################################
# Message Passing

sub as_array {
	TRACE($_[0]) if DEBUG;
	my $self = shift;
	my $task = $self->task;
	return [
		$self->hid,
		Scalar::Util::blessed($task),
		$task->as_string,
	];
}

sub from_array {
	TRACE($_[0]) if DEBUG;
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

# Serialize and pass-through to the Wx signal dispatch
sub message {
	TRACE($_[0]) if DEBUG;
	Padre::Wx::Role::Conduit->signal(
		Storable::freeze( [ shift->hid, @_ ] )
	);
}

sub on_message {
	TRACE($_[0]) if DEBUG;
	my $self   = shift;
	my $method = shift;

	# Does the method exist
	unless ( $self->{task}->can($method) ) {
		# A method name provided directly by the Task
		# doesn't exist in the Task. Naughty Task!!!
		# Lacking anything more sane to do, squelch it.
		return;
	}

	# Pass the call down to the task and protect it from itself
	local $@;
	eval {
		$self->{task}->$method(@_);
	};
	if ( $@ ) {
		# A method in the main thread blew up.
		# Beyond catching it and preventing it killing
		# Padre entirely, I'm not sure what else we can
		# really do about it at this point.
		return;
	}

	return;
}

# Task startup handling
sub started {
	TRACE($_[0]) if DEBUG;
	$_[0]->message( 'STARTED' );
}

# There is no on_stopped atm... not sure if it's needed.
# sub on_started { ... }

# Task shutdown handling
sub stopped {
	TRACE($_[0]) if DEBUG;
	$_[0]->message( 'STOPPED', $_[0]->{task} );
}

sub on_stopped {
	TRACE($_[0]) if DEBUG;
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
	eval {
		$self->{task}->finish;
	};
	if ( $@ ) {
		# A method in the main thread blew up.
		# Beyond catching it and preventing it killing
		# Padre entirely, I'm not sure what else we can
		# really do about it at this point.
		return;
	}

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
