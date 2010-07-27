package Padre::TaskThread;

# Cleanly encapsulated object for a thread that does work based
# on packaged method calls passed via a shared queue.

use 5.008005;
use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Queue 2.11;
use Scalar::Util ();

# NOTE: Don't use Padre::Wx here, by only loading the Wx core
# we can have less of Wx loaded when we spawn the master thread.
# Given that background threads shouldn't be using Wx anyway,
# loaded less code now cuts the per-thread cost of several meg.
use Wx ();

our $VERSION = '0.68';

# Worker id sequence, so identifiers will be available in objects
# across all instances and threads before the thread has been spawned.
# We map the worker ID to the thread id, once it exists.
my $SEQUENCE : shared = 0;
my %WID2TID : shared  = ();




######################################################################
# Slave Master Support (main thread only)

my $SINGLETON = undef;

sub master {
	$SINGLETON
		or $SINGLETON = shift->new->spawn;
}

# Handle master initialisation
sub import {
	if ( defined $_[1] and $_[1] eq ':master' ) {
		$_[0]->master;
	}
}





######################################################################
# Constructor and Accessors

sub new {

	# TRACE($_[0]) if DEBUG;
	bless {
		wid   => ++$SEQUENCE,
		queue => Thread::Queue->new,
		},
		$_[0];
}

sub wid {

	# TRACE($_[0]) if DEBUG;
	$_[0]->{wid};
}

sub queue {

	# TRACE($_[0])          if DEBUG;
	# TRACE($_[0]->{queue}) if DEBUG;
	$_[0]->{queue};
}





######################################################################
# Main Methods

sub spawn {

	# TRACE($_[0]) if DEBUG;
	my $self = shift;

	# Spawn the object into the thread and enter the main runloop
	$WID2TID{ $self->{wid} } = threads->create(
		sub {
			$_[0]->run;
		},
		$self,
	)->tid;

	return $self;
}

sub tid {

	# TRACE($_[0]) if DEBUG;
	$WID2TID{ $_[0]->{wid} };
}

sub thread {

	# TRACE($_[0]) if DEBUG;
	threads->object( $_[0]->tid );
}

sub join {

	# TRACE($_[0]) if DEBUG;
	$_[0]->thread->join;
}

sub is_thread {

	# TRACE($_[0]) if DEBUG;
	$_[0]->tid == threads->self->tid;
}

sub is_running {

	# TRACE($_[0]) if DEBUG;
	$_[0]->thread->is_running;
}

sub is_joinable {

	# TRACE($_[0]) if DEBUG;
	$_[0]->thread->is_joinable;
}

sub is_detached {

	# TRACE($_[0]) if DEBUG;
	$_[0]->thread->is_detached;
}





######################################################################
# Parent Thread Methods

sub send {

	# TRACE($_[0]) if DEBUG;
	my $self   = shift;
	my $method = shift;
	unless ( _CAN( $self, $method ) ) {
		die("Attempted to send message to non-existant method '$method'");
	}

	# Add the message to the queue
	$self->{queue}->enqueue( [ $method, @_ ] );

	return 1;
}

# Add a worker object to the pool, spawning it from the master
sub start {

	# TRACE($_[0]) if DEBUG;
	shift->send( 'start_child', @_ );
}

# Immediately detach and terminate when queued jobs are completed
sub stop {

	# TRACE($_[0]) if DEBUG;
	# TRACE("Detaching thread") if DEBUG;
	$_[0]->thread->detach;
	$_[0]->send('stop_child');
}





######################################################################
# Child Thread Methods

sub run {

	# TRACE($_[0]) if DEBUG;
	my $self  = shift;
	my $queue = $self->{queue};

	# Loop over inbound requests
	# TRACE("Entering worker run-time loop") if DEBUG;
	while ( my $message = $queue->dequeue ) {

		# TRACE("Worker received message '$message->[0]'") if DEBUG;
		unless ( _ARRAY($message) ) {

			# warn("Message is not an ARRAY reference");
			next;
		}

		# Check the message type
		my $method = shift @$message;
		unless ( _CAN( $self, $method ) ) {

			# warn("Illegal message type");
			next;
		}

		# Hand off to the appropriate method.
		# Methods must return true, otherwise the thread
		# will abort processing and end.
		$self->$method(@$message) or last;
	}

	# TRACE("Exited worker run-time loop") if DEBUG;
	return;
}





######################################################################
# Message Handlers

# Spawn a worker object off the current thread
sub start_child {

	# TRACE($_[0]) if DEBUG;
	$_[1]->spawn;
	return 1;
}

# Stop the current child
sub stop_child {

	# TRACE($_[0]) if DEBUG;
	return 0;
}

# Execute a task
sub task {

	# TRACE($_[0]) if DEBUG;
	require Padre::TaskHandle;
	Padre::TaskHandle->from_array( $_[1] );
}





######################################################################
# Support Methods

sub _ARRAY {
	( ref $_[0] eq 'ARRAY' and @{ $_[0] } ) ? $_[0] : undef;
}

sub _CAN {
	( Scalar::Util::blessed( $_[0] ) and $_[0]->can( $_[1] ) ) ? $_[0] : undef;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
