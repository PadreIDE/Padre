package Padre::Wx::Diff;

use 5.008;
use strict;
use warnings;
use Scalar::Util      ();
use Params::Util      ();
use Padre::Role::Task ();
use Padre::Wx         ();
use Padre::Util       ();
use Padre::Logger;

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Role::Task
};





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $main  = shift;

	my $self = bless {@_}, $class;
	$self->{main} = $main;

	return $self;
}





#####################################################################
# Event Handlers


######################################################################
# Padre::Role::Task Methods

sub task_finish {
	TRACE( $_[1] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $data = Params::Util::_ARRAY( $task->{data} ) or ( print "data is not an array", return );
	my $lock = $self->{main}->lock('UPDATE');

	my $editor = $self->{main}->current->editor;

	# Clear any old content
	$self->clear;

	my @diffs = @{$data};
	for my $diff_chunk (@diffs) {
		for my $diff ( @{$diff_chunk} ) {
			my @diff = @$diff;
			my ( $type, $line, $text ) = @$diff;

			#print "$type, $line, $text\n";
			$editor->MarkerAdd( $line, ( $type eq '+' ) ? Padre::Wx::MarkAddition : Padre::Wx::MarkDeletion );
		}
	}

	return 1;
}

######################################################################
# General Methods

sub clear {
	my $self   = shift;
	my $editor = $self->{main}->current->editor;

	$editor->MarkerDeleteAll(Padre::Wx::MarkAddition);
	$editor->MarkerDeleteAll(Padre::Wx::MarkDeletion);
}

sub refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;
	my $lock     = $self->{main}->lock('UPDATE');

	# Cancel any existing diff task
	$self->task_reset;

	# Hide the widgets when no files are open
	unless ($document) {
		$self->clear;
		return;
	}

	# Shortcut if there is nothing to search for
	if ( $document->is_unused ) {
		return;
	}

	# Trigger the task to fetch the refresh data
	$self->task_request(
		task     => 'Padre::Task::Diff',
		document => $document,
	);
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
