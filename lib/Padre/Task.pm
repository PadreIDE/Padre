package Padre::Task;

use 5.008005;
use strict;
use warnings;
use Storable          ();
use Scalar::Util      ();
use Params::Util      ();
use Padre::Current    ();
use Padre::Role::Task ();

our $VERSION = '0.66';

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Check parameters for the object that owns the task
	if ( exists $self->{owner} ) {
		if ( exists $self->{callback} ) {
			unless ( Params::Util::_IDENTIFIER( $self->{callback} ) ) {
				die "Task 'callback' must be a method name";
			}
		}
		my $callback = $self->callback;
		unless ( $self->{owner}->can($callback) ) {
			die "Task callback '$callback' is not defined";
		}
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

sub callback {
	$_[0]->{callback} || 'task_response';
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
		my $callback = $self->callback;
		$owner->$callback($self);
	}
	return 1;
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

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
