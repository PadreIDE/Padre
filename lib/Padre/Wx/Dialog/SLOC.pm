package Padre::Wx::Dialog::SLOC;

# Project source lines of code calculator

use 5.008;
use strict;
use warnings;
use Padre::SLOC            ();
use Padre::Role::Task      ();
use Padre::Wx::Role::Main  ();
use Padre::Wx::Role::Timer ();
use Padre::Wx::FBP::SLOC   ();

our $VERSION = '0.95';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::Main
	Padre::Wx::Role::Timer
	Padre::Wx::FBP::SLOC
};





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Clear and reset all state
	$self->clear;

	return $self;
}





######################################################################
# Padre::Role::Task Methods

sub refresh {
	my $self = shift;

	# Reset any existing state
	$self->clear;

	# Find the current project
	my $project = $self->current->project or return;

	# Set the project title
	$self->{root} = $project->root;

	# Kick off the SLOC counting task
	$self->task_request(
		task    => 'Padre::Task::SLOC',
		project => $project,
	);

	# Start the render timer
	$self->poll_start( render => 1000 );

	return 1;
}

sub task_message {
	my $self = shift;
	my $task = shift;
	my $path = shift;
	my $sloc = shift;

	$DB::single = 1;

	1;
}





######################################################################
# Main Methods

sub run {
	my $class = shift;
	my $self  = $class->new(@_);

	# Kick off a fresh SLOC scanning run
	$self->refresh;

	# Show the dialog
	$self->ShowModal;

	# Clean up
	$self->poll_stop('render');
	$self->Destroy;
}

sub clear {
	my $self = shift;
	$self->poll_stop('render');
	$self->task_reset;
	$self->{files} = 0;
	$self->{sloc}  = Padre::SLOC->new;
	return 1;
}

1;
