package Padre::Wx::Role::Conduit;

=pod

=head1 NAME

Padre::Wx::Role::Conduit - Role to allow an object to receive Wx events

=head1 DESCRIPTION

This is a role that provides the functionality needed to receive Wx thread
events.

However, you should only use this role once, in the parent process.

It is implemented as a role so that the functionality can be used across the
main process and various testing classes (and will be easier to turn into a
CPAN spinoff later).

=cut

use 5.008;
use strict;
use warnings;
use Storable ();
use Wx       ();
use Padre::Logger;

our $VERSION = '0.94';

our $SIGNAL : shared;

BEGIN {
	$SIGNAL = Wx::NewEventType();
}

my $CONDUIT = undef;
my $HANDLER = undef;

sub handler {
	$HANDLER = $_[1];
}

sub conduit_init {
	TRACE( $_[0] ) if DEBUG;
	$CONDUIT = $_[0];
	$HANDLER = $_[1];
	Wx::Event::EVT_COMMAND( $CONDUIT, -1, $SIGNAL, \&on_signal );
	return 1;
}

sub signal {
	TRACE( $_[0] ) if DEBUG;
	if ($CONDUIT) {
		$CONDUIT->AddPendingEvent( Wx::PlThreadEvent->new( -1, $SIGNAL, $_[1] ) );
	} elsif (DEBUG) {
		TRACE("Cannot send Wx::PlThreadEvent as \$CONDUIT is undef");
	}
	return 1;
}

# Pass the event through to the event handler
sub on_signal {
	TRACE( $_[1] ) if DEBUG;
	return 1 unless $HANDLER;

	# Deserialise the message from the Wx event so that our handler does not
	# need to be aware we are implemented via Wx.
	my $frozen = $_[1]->GetData;
	my $message = eval { Storable::thaw($frozen); };
	if ($@) {
		TRACE("Exception deserialising message '$frozen'") if DEBUG;
		return;
	}

	$HANDLER->on_signal($message);
	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
