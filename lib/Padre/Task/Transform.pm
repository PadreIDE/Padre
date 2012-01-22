package Padre::Task::Transform;

# A Transform task is used to automatically calculate and apply a change
# to the content of a Padre::Wx::Transform.
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

use 5.008;
use strict;
use warnings;
use Storable          ();
use Params::Util      ();
use Padre::Role::Task ();

our $VERSION    = '0.94';
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

	# Check the transform object
	unless ( Params::Util::_INSTANCE($self->{transform}, 'Padre::Transform') ) {
		die "The transform param is not a Padre::Transform object";
	}

	return $self;
}

sub transform {
	$_[0]->{transform};
}

sub prepare {
	my $self   = shift;
	my $owner  = $self->{owner};
	my $editor = Padre::Role::Task->task_owner($owner) or return;
	my $text   = $editor->GetText;
	$self->{input} = \$text;
	return 1;
}

sub run {
	my $self   = shift;
	my $input  = delete $self->{input};
	my $delta  = $self->transform->scalar_delta($input);
	$self->{delta} = $delta;
	return 1;
}

# Apply the resulting delta to the editor, if it still exists
sub finish {
	my $self   = shift;
	my $editor = Padre::Role::Task->task_owner($self->{owner}) or return;
	my $delta  = $self->{delta} or return;
	$delta->to_editor($editor);
	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
