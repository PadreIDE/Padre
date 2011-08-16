package Padre::TaskProcess;

use 5.008;
use strict;
use warnings;
use Carp        ();
use Padre::Task ();

our $VERSION = '0.90';
our @ISA     = 'Padre::Task';





######################################################################
# Process API Methods

# Pass upstream to our handle
sub message {
	my $self = shift;

	# Check the message
	my $method = shift;
	unless ( $self->running ) {
		croak("Attempted to send message while not in a worker thread");
	}
	unless ( $method and $self->can($method) ) {
		croak("Attempted to send message to non-existant method '$method'");
	}

	# Hand off to our parent handle
	$self->handle->message( $method, @_ );
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
