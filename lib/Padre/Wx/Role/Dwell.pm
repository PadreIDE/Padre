package Padre::Wx::Role::Dwell;

=pod

=head1 NAME

Padre::Wx::Role::Dwell - Convenience methods for implementing dwell timers

=head1 DESCRIPTION

This role implements a set of methods for letting Wx objects in Padre
implement dwell events on elements that do not otherwise natively
support them.

In this initial simplified implementation, we support only one common
dwell event for each combination of object class and dwell method.

If multiple instances of a class are used, then the timer id will collide
across multiple timers and unexpected behaviour may occur.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.94';

# Track timer Wx id values for each dwell event
my %ID = ();





######################################################################
# Dwell Interface Methods

=pod

=head2 dwell_start

  # Half second dwell timer on a text input
  $wx_object->dwell_start( 'on_text', 500 );

The C<dwell_start> method starts (or restarts) the dwell timer.

It has two required parameters of the method to call, and the amount of
time (in thousands of a second) that the event should be delayed.

Note that when the dwell-delayed event is actually called, it will NOT be
passed the original Wx event object. The method will be called directly
and with no parameters.

Please note that calling this method will result in the creating of a
L<Wx::Timer> object in an object HASH slot that matches the name of the
method.

As a result, if you wish to create a dwell to a method "foo" you may never
make use of the C<$wx_object-E<gt>{foo}> slot on that object.

=cut

sub dwell_start {
	my $self   = shift;
	my $method = shift;
	my $msec   = shift;

	# If this is the first time the dwell event is being called
	# create the timer object to support the dwell.
	unless ( $self->{$method} ) {

		# Fetch a usable id for the timer
		my $name = ref($self) . '::' . $method;
		my $id = ( $ID{$name} or $ID{$name} = Wx::NewId() );

		# Create the reusable timer object
		$self->{$method} = Wx::Timer->new( $self, $id );
		Wx::Event::EVT_TIMER(
			$self, $id,
			sub {
				$self->$method();
			},
		);
	}

	# Start (or restart) the dwell timer.
	$self->{$method}->Start( $msec, Wx::TIMER_ONE_SHOT );
}

=pod

=head2 dwell_stop

  $wx_object->dwell_stop( 'on_text' );

The C<dwell_stop> method prevents a single named dwell event from firing,
if there is a timer underway.

If there is no dwell for the named event the method will silently succeed.

=cut

sub dwell_stop {
	my $self   = shift;
	my $method = shift;
	if ( $self->{$method} ) {
		$self->{$method}->Stop;
	}
	return 1;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
