package Padre::Queue;

# Basic scripting for Padre

=pod

=head1 NAME

Padre::Queue doesn't create any actions itself but it provides a basic
scripting option for Padre, the Action Queue.

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx      ();
use Padre::Current ();

our $VERSION = '0.66';

sub new {
	my $class = shift;
	my $main  = Padre::Current->main;

	# Create the empty queue
	my $self = bless {
		actions => Padre::Current->ide->actions,
		Queue   => [],
	}, $class;

	# Create the Wx timer
	$self->{timer} = Wx::Timer->new(
		$main,
		Padre::Wx::ID_TIMER_ACTIONQUEUE
	);
	Wx::Event::EVT_TIMER(
		$main,
		Padre::Wx::ID_TIMER_ACTIONQUEUE,
		sub {
			$self->on_timer( $_[1], $_[2] );
		},
	);
	$self->{timer}->Start(1000);

	return $self;
}

sub add {
	my $self = shift;
	push @{ $self->{Queue} }, @_;
	return 1;
}

sub set_timer_interval {
	my $self = shift;

	# Get current interval
	my $interval = 0;
	$interval = $self->{timer} if $self->{timer}->IsRunning;

	my $new_interval;
	if ( $#{ $self->{Queue} } == -1 ) {

		# No pending queue actions
		$new_interval = 1000;
	} else {

		# Pending actions, execute one of them each 250ms
		$new_interval = 250;
	}

	# Do nothing if interval is unchanged
	return 1 if $interval == $new_interval;

	# Reset the timer interval
	$self->{timer}->Stop if $self->{timer}->IsRunning;
	$self->{timer}->Start($new_interval);

	return 1;
}

sub on_timer {
	my $self  = shift;
	my $event = shift;
	my $force = shift;

	if ( $#{ $self->{Queue} } > -1 ) {

		# Advoid another timer event during processing of this event
		$self->{timer}->Stop;

		my $queue  = $self->{Queue};
		my $action = shift @$queue;
		if ( $self->{debug} ) {
			my $now = scalar localtime time;
			print STDERR "$now Action::Queue $action\n";
		}

		# Run the event handler
		my $main = Padre::Current->main;
		&{ $self->{actions}->{$action}->{queue_event} }( $main, $event, $force );

		# Reset not needed if timer wasn't stopped
		$self->set_timer_interval;
	}

	$event->Skip(0) if defined $event;

	return 1;

}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
