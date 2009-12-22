package Padre::Lock;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.52';

sub new {
	my $class  = shift;
	my $locker = shift;
	my $self   = bless [$locker], $class;

	# Enable the locks
	my $busy   = 0;
	my $update = 0;
	foreach (@_) {
		if ( $_ eq 'BUSY' ) {
			$locker->busy_increment;
			$busy = 1;

		} elsif ( $_ eq 'UPDATE' ) {
			$locker->update_increment;
			$update = 1;

		} else {
			$locker->method_increment($_);
			push @$self, $_;
		}
	}

	# We always want to unlock busy/update stuff last
	push @$self, 'BUSY'   if $busy;
	push @$self, 'UPDATE' if $update;

	return $self;
}

# Disable locking on destruction
sub DESTROY {
	my $locker = shift @{ $_[0] };
	foreach ( @{ $_[0] } ) {
		if ( $_ eq 'UPDATE' ) {
			$locker->update_decrement;
		} elsif ( $_ eq 'BUSY' ) {
			$locker->busy_decrement;
		} else {
			$locker->method_decrement($_);
		}
	}
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
