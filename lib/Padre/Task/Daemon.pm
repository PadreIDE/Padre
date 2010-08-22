package Padre::Task::Daemon;

use 5.008005;
use strict;
use warnings;
use Params::Util ();
use Padre::Logger;

our $VERSION = '0.69';
our @ISA     = 'Padre::Task';

sub dequeue {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $handle = $self->handle or return 0;

	# Pull from the inbox first
	my $inbox  = $handle->inbox or return 0;
	if ( @$inbox ) {
		return shift @$inbox;
	}

	# Pull off the queue
	my $queue = $handle->queue or return 0;
	push @$inbox, $queue->dequeue;
	my $message = shift @$inbox or return 0;

	# Check the message for valid structure
	unless ( Params::Util::_ARRAY($message) ) {
		TRACE('Non-ARRAY message received by a worker thread') if DEBUG;
		return 0;
	}
	unless ( _IDENTIFIER( $message->[0] ) ) {
		TRACE('Non-method message received by worker thread') if DEBUG;
		return 0;
	}

	return $message;
}

sub dequeue_nb {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $handle = $self->handle or return 0;

	# Pull from the inbox first
	my $inbox  = $handle->inbox or return 0;
	if ( @$inbox ) {
		return shift @$inbox;
	}

	# Pull off the queue, non-blocking
	my $queue = $handle->queue or return 0;
	push @$inbox, $queue->dequeue_nb;
	my $message = shift @$inbox or return 0;

	# Check the message for valid structure
	unless ( Params::Util::_ARRAY($message) ) {
		TRACE('Non-ARRAY message received by a worker thread') if DEBUG;
		return 0;
	}
	unless ( _IDENTIFIER( $message->[0] ) ) {
		TRACE('Non-method message received by worker thread') if DEBUG;
		return 0;
	}

	return $message;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
