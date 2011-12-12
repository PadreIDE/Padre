package Padre::Task::Editor;

# An Editor task is used to automatically calculate and apply a change
# to the content of a Padre::Wx::Editor.
# 
# It does so via the following steps:
#
# 1. Apply a readonly lock to the editor
# 2. Capture the text content of the editor
# 3. Send the content to the background for transformation
# 4. Transform the content in the background
# 5. Calculate a Padre::Delta to apply the changes
# 6. Return the delta to the foreground
# 7. Apply the delta to the editor and release the lock

use strict;
use warnings;
use Storable          ();
use Params::Util      ();
use Padre::Role::Task ();

our $VERSION    = '0.93';
our $COMPATIBLE = '0.93';
our @ISA        = 'Padre::Task';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# We must have an owner and it must be an editor
	my $editor = Padre::Role::Task->task_owner($self->{owner});
	unless ( Params::Util::_INSTANCE($editor, 'Padre::Wx::Editor') ) {
		die "Task owner is not a Padre::Wx::Editor object";
	}

	# Attempt to take a lock on the editor
	$self->{lock} = $editor->lock_readonly;
	unless ( $self->{lock} ) {
		die "Failed to take a lock on the editor";
	}

	return $self;
}

sub prepare {
	my $self   = shift;
	my $owner  = $self->{owner};
	my $editor = Padre::Role::Task->task_owner($owner) or return;
	my $text   = $editor->GetText;
	$self->{input} = \$text;
	return 1;
}

sub as_string {
	my $self = shift;
	my $copy = { %$self };
	delete $copy->{lock};
	return Storable::nfreeze($copy);
}

sub run {
	my $self   = shift;
	my $input  = delete $self->{input};
	my $output = $self->transform($input);
	if ( Params::Util::_SCALAR($output) ) {
		require Padre::Delta;
		$output = Padre::Delta->from_scalar( $input => $output );
	}
	unless ( Params::Util::_INSTANCE($output, 'Padre::Delta') ) {
		return;
	}
	$self->tell_parent($output);
	return 1;
}





######################################################################
# Default Null Transform

sub transform {
	my $self  = shift;
	my $input = shift;
	return $input;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
