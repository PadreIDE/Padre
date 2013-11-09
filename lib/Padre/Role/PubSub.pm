package Padre::Role::PubSub;

=pod

=head1 NAME

Padre::Role::PubSub - A simple event publish/subscriber role

=head1 DESCRIPTION

This class allows the addition of simple publish/subscribe behaviour to an
arbitrary class.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Scalar::Util ();
use Params::Util ();
our $VERSION = '1.00';
=pod

=head2 subscribe

  $publisher->subscriber( $object, {
      my_event_one => 'my_handler_method',
      my_event_two => 'my_handler_method',
  } );

The <subscriber> method lets you register an object for callbacks to a
particular set of method for various named events.

Returns true, or throws an exception if any of the parameters are invalid.

=cut

sub subscribe {
	my $self   = shift;
	my $object = shift;
	my $events = shift;
	unless ( Params::Util::_INSTANCE($object, 'UNIVERSAL') ) {
		die "Missing or invalid subscriber object";
	}
	unless ( Params::Util::_HASH($events) ) {
		die "Missing or invalid event hash method";
	}

	# Create the new queue entry
	my $queue = $self->{pubsub} ||= [];
	push @$queue, [ $object, $events ];
	Scalar::Util::weaken($queue->[-1]->[0]);

	return 1;
}

=pod

=head2 unsubscribe

  $publisher->unsubscribe($subscriber);

The C<unsubscribe> method removes all event registrations for a particular
object.

Returns true.

=cut

sub unsubscribe {
	my $self  = shift;
	my $queue = $self->{pubsub} or return 1;
	my $addr  = Scalar::Util::refaddr(shift) or return 1;
	@$queue = map { defined $_ and Scalar::Util::refaddr($_) != $addr } @$queue;
	delete $self->{pubsub} unless @$queue;
	return 1;
}

=pod

=head2 publish

  $publisher->publish("my_event_one", "param1", "param2");

The C<publish> method is called on the published to emit a particular named
event.

It calls any registered event handlers in sequence, ignoring exceptions.

Returns true, or throws an exception if the event name is invalid.

=cut

sub publish {
	my $self  = shift;
	my $queue = $self->{pubsub} or return 1;
	my $name  = shift;

	# Iterate over the subscribers, calling them and ignoring their response
	foreach my $subscriber ( @$queue ) {
		next unless defined $subscriber->[0];
		my $object = $subscriber->[0];
		my $method = $subscriber->[1]->{$name} or next;
		$object->$method( $self, @_ );
	}

	return 1;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
