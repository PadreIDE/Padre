package Padre::Wx::Role::Conduit;

=pod

=head1 NAME

Padre::Wx::Role::Conduit - Role to allow an object to receive Wx events

=head1 SYNOPSIS

  package My::MainFrame;
  
  use strict;
  use Padre::Wx                ();
  use Padre::Wx::Role::Conduit ();
  use My::ChildHandler         ();
  
  our @ISA = qw{
      Padre::Wx::Role::Conduit
      Wx::Frame
  };
  
  sub new {
      my $class = shift;
      my $self  = $class->SUPER::new(@_);
  
      # Register to receive events    
      $self->conduit_init( My::ChildHander->singleton );
  
      return $self;
  }

=head1 DESCRIPTION

This role provides the functionality needed to receive L<Wx::PlThreadEvent>
objects from child threads.

You should only use this role once and once only in the parent process,
and then allow that single event conduit to pass the events on to the other
parts of your program, or to some dispatcher object that will do so.

It is implemented as a role so that the functionality can be used across the
main process and various testing classes (and will be easier to turn into a
CPAN spinoff later).

=head1 PARENT METHODS

=cut

use 5.008;
use strict;
use warnings;
use Storable ();
use Wx       ();

our $VERSION = '1.00';

our $SIGNAL : shared;

BEGIN {
	$SIGNAL = Wx::NewEventType();
}

my $CONDUIT = undef;
my $HANDLER = undef;

=pod

=head2 conduit_init

  $window->conduit_init($handler);

The C<conduit_init> method is called on the parent receiving object once it
has been created.

It takes the handler that deserialised messages should be passed to once
they have been extracted from the incoming L<Wx::PlThreadEvent> and
deserialised into a message structure.

=cut

sub conduit_init {
	$CONDUIT = $_[0];
	$HANDLER = $_[1];
	Wx::Event::EVT_COMMAND( $CONDUIT, -1, $SIGNAL, \&on_signal );
	return 1;
}

=pod

=head2 handler

  $window->handler($handler);

The C<handler> accessor is a convenience method that allows you to change
the message handler after the conduit has been initialised.

=cut

sub handler {
	$HANDLER = $_[1];
}

=pod

=head2 on_signal

  $window->on_signal( $pl_thread_event );

The C<on_signal> method is called by the L<Wx> system on the parent object
when a L<Wx::PlThreadEvent> arrives from a child thread.

The default implementation will extra the packaged data for the event,
deserialise it, and then pass off the C<on_signal> method of the handler.

You might overload this method if you need to something exotic with the
event handling, but this is highly unlikely and this documentation is
provided only for completeness.

=cut

sub on_signal {
	if ($HANDLER) {

		# Deserialise the message from the Wx event so that our handler does not
		# need to be aware we are implemented via Wx.
		my $frozen = $_[1]->GetData;
		local $@;
		my $message = eval { Storable::thaw($frozen) };
		return if $@;
		$HANDLER->on_signal($message);
	}
	return 1;
}

=pod

=head2 signal

  Padre::Wx::Role::Conduit->signal(
      Storable::freeze( [ 'My message' ] )
  );

The static C<signal> method is called in child threads to send a message
to the parent window. The message can be any legal Perl structure that has
been serialised by the L<Storable> module.

=cut

sub signal {

	# We use Wx::PostEvent rather than AddPendingEvent because this
	# function passes the data through a thread-safe stash.
	# Using AddPendingEvent directly will cause occasional segfaults.
	if ($CONDUIT) {
		Wx::PostEvent(
			$CONDUIT,
			Wx::PlThreadEvent->new(
				-1,
				$SIGNAL,
				Storable::freeze( $_[1] ),
			),
		);
	}
	return 1;
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
