package Padre::Lock;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.50';

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Enable the locks
	if ( $self->{update} ) {
		$self->{locker}->update_enable;
	}
	if ( $self->{busy} ) {
		$self->{locker}->busy_enable;
	}

	return $self;
}

sub DESTROY {

	# Disable the locks
	if ( $_[0]->{update} ) {
		$_[0]->{locker}->update_disable;
	}
	if ( $_[0]->{busy} ) {
		$_[0]->{locker}->busy_disable;
	}
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
