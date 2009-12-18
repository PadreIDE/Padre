package Padre::Lock;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.52';

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Enable the locks
	if ( $self->{UPDATE} ) {
		$self->{locker}->update_enable;
	}
	if ( $self->{BUSY} ) {
		$self->{locker}->busy_enable;
	}

	return $self;
}

# Disable locking on destruction
sub DESTROY {
	if ( $_[0]->{UPDATE} ) {
		$_[0]->{locker}->update_disable;
	}
	if ( $_[0]->{BUSY} ) {
		$_[0]->{locker}->busy_disable;
	}
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
