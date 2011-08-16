package Padre::TaskWorker;

# Object that represents the worker thread

use 5.008005;
use strict;
use warnings;
use Scalar::Util      ();
use Padre::TaskThread ();
use Padre::Logger;

our $VERSION = '0.90';
our @ISA     = 'Padre::TaskThread';





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Initialise task statistics
	$self->{seen} = {};

	return $self;
}





######################################################################
# Main Thread Methods

sub send_task {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $handle = shift;

	# Tracking for the relationship between the worker and task handle
	$handle->worker( $self->wid );
	$self->{handle} = $handle->hid;
	$self->{seen}->{ $handle->class } += 1;

	# Send the message to the child
	TRACE( "Handle " . $handle->hid . " being sent to worker " . $self->wid ) if DEBUG;
	$self->send( 'task', $handle->as_array );
}

sub handle {
	my $self = shift;
	$self->{handle} = shift if @_;
	return $self->{handle};
}





######################################################################
# Worker Thread Methods

sub task {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Deserialize the task handle
	TRACE("Loading Padre::TaskHandle") if DEBUG;
	require Padre::TaskHandle;
	TRACE("Inflating handle object") if DEBUG;
	my $handle = Padre::TaskHandle->from_array(shift);

	# Execute the task (ignore the result) and signal as we go
	local $@;
	eval {
		my $hid = $handle->hid;
		TRACE("Handle $hid calling ->started") if DEBUG;
		$handle->{child} = 1;
		$handle->{queue} = $self->queue;
		$handle->started;
		TRACE("Handle $hid calling ->run") if DEBUG;
		$handle->run;
		TRACE("Handle $hid calling ->stopped") if DEBUG;
		$handle->stopped;
		delete $handle->{queue};
		delete $handle->{child};
	};
	delete $handle->{child};
	if ($@) {
		delete $handle->{queue};
		delete $handle->{child};
		TRACE($@) if DEBUG;
	}

	# Continue to the next task
	return 1;
}

# Any messages that arrive when we are NOT actively running a task
# should be discarded with no consequence.
sub message {
	TRACE( $_[0] ) if DEBUG;
	TRACE("Discarding message '$_[1]->[0]'") if DEBUG;
}

# A cancel request that arrives when we are NOT active running a task
# should be discarded with no consequence.
sub cancel {
	if (DEBUG) {
		TRACE( $_[0] );
		if ( defined $_[1]->[0] ) {
			TRACE("Discarding message '$_[1]->[0]'");
		} else {
			TRACE("Discarding undefined message");
		}
	}
	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
