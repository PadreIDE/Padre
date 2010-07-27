package Padre::Role::Task;

=pod

=head1 NAME

Padre::Role::Task - A role for objects that commission tasks

=head1 DESCRIPTION

This is a role that should be inherited from by objects in Padre's
permanent model that want to commision tasks to be run and have the
results fed back to them, if the answer is still relevant.

=cut

use 5.008005;
use strict;
use warnings;
use Scalar::Util ();

our $VERSION = '0.68';

# Use a shared sequence for object revisioning greatly
# simplifies the indexing process.
my $SEQUENCE = 0;
my %INDEX    = ();





######################################################################
# Statefulness

# Get the object's current revision
sub task_revision {
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

	return $self->{task_revision};
}

# Object state has changed, update revision and flush index.
sub task_reset {
	my $self = shift;
	if ( $self->{task_revision} ) {
		delete $INDEX{ $self->{task_revision} };
	}
	$self->{task_revision} = ++$SEQUENCE;
}

# Locate an object by revision
sub task_owner {
	$INDEX{ $_[1] };
}

# Create a new task bound to the owner
sub task_request {
	my $self  = shift;
	my %param = @_;

	# Check and load the task
	# Support a convenience shortcut where a false value
	# for task means don't run a task at all.
	my $task = delete $param{task} or return;
	my $class = Params::Util::_DRIVER(
		$task,
		'Padre::Task',
	) or die "Missing or invalid task class '$task'";

	# Create and start the task with ourself as the owner
	$class->new( owner => $self, %param )->schedule;
}

# By default explode to highlight task requesters that
# have not implemented an appropriate response handler.
sub task_response {
	my $class = ref( $_[0] ) || $_[0];
	my $task  = ref( $_[1] ) || $_[1];
	die "Unhandled task_response for $class (recieved $task)";
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
