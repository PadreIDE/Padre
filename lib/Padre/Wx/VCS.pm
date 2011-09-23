package Padre::Wx::VCS;

use 5.008;
use strict;
use warnings;
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx             ();
use Padre::Logger;

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
};

# Constructor
sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;
	my $self  = $class->SUPER::new($panel);

	return $self;
}

######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {

	#TODO properly implement view_close
	#$_[0]->main->show_vcs(0);
}

sub view_start {
}

sub view_stop {
	my $self = shift;
	my $main = $self->main;
	my $lock = $main->lock('UPDATE');

	# Clear out any state and tasks
	$self->task_reset;
	$self->clear;

	return;
}

#####################################################################
# Event Handlers

#####################################################################
# General Methods

sub gettext_label {
	Wx::gettext('Version Control');
}

# Clear everything...
sub clear {
	my $self = shift;
	my $lock = $self->main->lock('UPDATE');

	return;
}

# Nothing to implement here
sub relocale {
	return;
}

sub refresh {
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;
	my $lock     = $self->main->lock('UPDATE');

	# Abort any in-flight checks
	$self->task_reset;

	# Hide the widgets when no files are open
	unless ($document) {
		$self->clear;
		return;
	}

	# Shortcut if there is nothing in the document to compile
	if ( $document->is_unused ) {
		return;
	}

	# Fire the background task discarding old results
	$self->task_request(
		task     => 'Padre::Task::VCS',
		document => $document,
	);

	return 1;
}

sub task_finish {
	my $self = shift;
	my $task = shift;
	$self->{model} = $task->{model};

	# TODO validate model

	$self->render;
}

sub render {
	my $self  = shift;
	my $model = $self->{model} || {};
	my $lock  = $self->main->lock('UPDATE');

	# Flush old results
	$self->clear;

	#TODO implement render

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
