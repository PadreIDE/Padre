package Padre::Wx::Role::Idle;

=pod

=head1 NAME

Padre::Wx::Role::Idle - Role for delaying method calls until idle time

=head1 SYNOPSIS

  # Manually schedule some work on idle
  $self->idle_method( my_method => 'param' );
  
  # Delay work until idle time in response to an event
  Wx::Event::EVT_TREE_ITEM_ACTIVATED(
      $self,
      $self,
      sub {
            shift->idle_method( my_method => 'param' );
      },
  );
  
  # The handler for the event
  sub my_method {
      my $self  = shift;
      my $param = shift;
      
      # Functionality is implemented here
  }

=head1 DESCRIPTION

This role provides a standard mechanism for delaying method call dispatch
until idle time.

The role maintains a dispatch queue for each object, binds or unbinds an
C<EVT_IDLE> handler depending on whether there is anything in the queue,
and dispatches one method from the queue each time idle is fired (to ensure
that any large series of tasks will be spread out over time instead of
all blocking at once on the first idle event).

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp      ();
use Padre::Wx ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.95';

=pod

=head2 idle_method

  $self->idle_method( method_name => @params );

The C<idle_method> method is used to schedule a method for execution at
idle time.

The first parameter to the call should be the name of the method to be
called on this object. The method will be checked before it is added to
the queue to ensure that it exists.

Any remaining parameters to C<idle_method> will be passed through as
parameters to the specified method call.

Please note that L<Wx::Event> objects B<must not be used> as paramters
to this method. While the Perl level object will survive until idle time,
the underlying Wx event structure for the event will no longer exist, and
any attempt to call a method on the event object will segfault Perl.

You should unpack any information you need from the L<Wx::Event> before
making the call to C<idle_method> and pass it through as data instead.

=cut

sub idle_method {
	my $self = shift;

	if ( $self->{idle} ) {

		# Add to the existing idle queue
		push @{ $self->{idle} }, [@_];

	} else {

		# Create the idle queue and bind the event
		$self->{idle} = [ [@_] ];
		$self->Connect(
			-1, -1,
			Wx::EVT_IDLE,
			sub {
				$_[0]->idle_handler( $_[1] );
			},
		);
	}
}

=pod

=head2 idle_handler

The C<idle_handler> method is called internally to dispatch the next
method in the idle queue.

It will dispatch one and only one call on the queue, returning true if
there are any remaining calls on the queue of false if the queue is empty.

While you generally should not need to know about this method, there are
two ways to use this method to influence the behaviour of the role.

Firstly, the method call be called directly to trigger the immediate
dispatch of an idle method without waiting for the C<EVT_IDLE> event
to fire.

Secondly, you could overload the C<idle_handler> method to add extra
functionality that should be run any time a delayed call of any other
type is made.

=cut

sub idle_handler {
	my $self = shift;
	my $idle = $self->{idle};

	# Process one item on the idle queue per idle call
	if ($idle) {
		my $call = shift @$idle;

		# Remove the idle handler if there are no other calls
		unless (@$idle) {
			$self->Disconnect( -1, -1, Wx::EVT_IDLE );
			delete $self->{idle};
		}

		# Dispatch the method call
		my $method = shift @$call;
		$self->$method(@$call);
	}

	return !!$self->{idle};
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
