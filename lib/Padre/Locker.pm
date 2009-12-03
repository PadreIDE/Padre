package Padre::Locker;

use 5.008;
use strict;
use warnings;
use Padre::Lock ();

our $VERSION = '0.50';

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the object
	my $self = bless {
		main          => $main,

		# Wx ->Update lock
		update_depth  => 0,
		update_locker => undef,

		# Wx "Busy" lock
		busy_depth    => 0,
		busy_locker   => undef,

		# Padre ->refresh lock
		refresh_depth  => 0,
		refresh_method => {},
	}, $class;
}

sub update_enable {
	my $self = shift;
	unless ( $self->{update_depth}++ ) {
		# Locking for the first time
		$self->{update_locker} = Wx::WindowUpdateLocker->new( $self->{main} );
	}
	return;
}

sub update_disable {
	my $self = shift;
	unless ( --$self->{update_depth} ) {
		# Unlocked for the final time
		$self->{update_locker} = undef;
	}
	return;
}

sub busy_enable {
	my $self = shift;
	unless ( $self->{busy_depth}++ ) {
		# Locking for the first time
		$self->{busy_locker} = Wx::WindowDisabler->new;
	}
	return;
}

sub busy_disable {
	my $self = shift;
	unless ( --$self->{busy_depth} ) {
		# Unlocked for the final time
		$self->{busy_locker} = undef;
	}
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
