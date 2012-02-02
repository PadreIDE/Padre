package Padre::Wx::Dialog::SLOC;

# Project source lines of code calculator

use 5.008;
use strict;
use warnings;
use Padre::SLOC            ();
use Padre::Locale::Format  ();
use Padre::Role::Task      ();
use Padre::Wx::Role::Main  ();
use Padre::Wx::Role::Timer ();
use Padre::Wx::FBP::SLOC   ();
use Padre::Logger;

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

	# Find the current project
	my $project = $self->current->project;
	return unless defined $project;

	# Set the project title
	$self->{root}->SetLabel( $project->root );

	# Reset any existing state
	$self->clear;

	# Kick off the SLOC counting task
	$self->task_request(
		task       => 'Padre::Task::SLOC',
		on_message => 'refresh_message',
		on_finish  => 'refresh_finish',
		project    => $project,
	);

	# Start the render timer
	$self->poll_start( render => 250 );

	return 1;
}

sub refresh_message {
	$_[0]->{count}++;
	$_[0]->{sloc}->add($_[3]);
}

# Do a final render and end the poll loop
sub refresh_finish {
	$_[0]->poll_stop('render');
	$_[0]->render;
}





######################################################################
# Main Methods

sub run {
	my $class = shift;
	my $self  = $class->new(@_);
	$self->refresh;
	$self->ShowModal;
	$self->poll_stop('render');
	$self->Destroy;
}

sub clear {
	my $self = shift;
	$self->poll_stop('render');
	$self->task_reset;
	$self->{count} = 0;
	$self->{sloc}  = Padre::SLOC->new;
	$self->render;
}

sub render {
	my $self = shift;
	my $lock = $self->lock_update;
	my $sloc = $self->{sloc}->report_types;

	$self->{files}->SetLabel(
		Padre::Locale::Format::integer( $self->{count} )
	);
	$self->{code}->SetLabel(
		Padre::Locale::Format::integer( $sloc->{code} || 0 )
	);
	$self->{comment}->SetLabel(
		Padre::Locale::Format::integer( $sloc->{comment} || 0 )
	);
	$self->{blank}->SetLabel(
		Padre::Locale::Format::integer( $sloc->{blank} || 0 )
	);

	$self->Fit;
	$self->Layout;
}

1;
