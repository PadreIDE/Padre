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

our $VERSION = '1.00';
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
	$_[0]->{sloc}->add( $_[3] );
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
	my $self    = shift;
	my $lock    = $self->lock_update;
	my $sloc    = $self->{sloc}->smart_types;
	my $count   = $self->{count};
	my $code    = $sloc->{code} || 0;
	my $comment = $sloc->{comment} || 0;
	my $blank   = $sloc->{blank} || 0;

	# Calculate Basic COCOMO Model values
	my $pax_months = 2.4 * ( $code / 1000 )**1.05;
	my $pax_years  = $pax_months / 12;
	my $cal_months = 2.5 * ( $pax_months**0.38 );
	my $cal_years  = $cal_months / 12;
	my $dev_count  = $cal_months ? $pax_months / $cal_months : 0;
	my $dev_salary = 56286;
	my $dev_cost   = $pax_years * $dev_salary * 2.4;

	$self->{files}->SetLabel( Padre::Locale::Format::integer($count) );
	$self->{code}->SetLabel( Padre::Locale::Format::integer($code) );
	$self->{comment}->SetLabel( Padre::Locale::Format::integer($comment) );
	$self->{blank}->SetLabel( Padre::Locale::Format::integer($blank) );
	$self->{pax_months}->SetLabel( sprintf( '%0.2f', $pax_months ) );
	$self->{cal_years}->SetLabel( sprintf( '%0.2f', $cal_years ) );
	$self->{dev_count}->SetLabel( sprintf( '%0.2f', $dev_count ) );
	$self->{dev_cost}->SetLabel( '$' . Padre::Locale::Format::integer( int $dev_cost ) );

	$self->Fit;
	$self->Layout;
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
