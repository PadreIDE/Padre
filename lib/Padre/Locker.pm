package Padre::Locker;

=pod

=head1 NAME

Padre::Locker - The Padre Multi-Resource Lock Manager

=cut

use 5.008;
use strict;
use warnings;
use Padre::Lock ();

our $VERSION = '0.52';

sub new {
	my $class = shift;
	my $owner = shift;

	# Create the object
	my $self = bless {
		owner => $owner,

		# Wx ->Update lock
		update_depth  => 0,
		update_locker => undef,

		# Wx "Busy" lock
		busy_depth  => 0,
		busy_locker => undef,

		# Padre ->refresh lock
		method_depth   => 0,
		method_pending => {},
	}, $class;
}

sub lock {
	Padre::Lock->new( shift, @_ );
}

sub locked {
	my $self  = shift;
	my $asset = shift;
	if ( $asset eq 'UPDATE' ) {
		return !! $self->{update_depth};
	} elsif ( $asset eq 'BUSY' ) {
		return !! $self->{busy_depth};
	} elsif ( $asset eq 'REFRESH' ) {
		return !! $self->{method_depth};
	} else {
		return !! $self->{method_pending}->{$asset};
	}
}





######################################################################
# Locking Mechanism

sub update_increment {
	my $self = shift;
	unless ( $self->{update_depth}++ ) {

		# Locking for the first time
		$self->{update_locker} = Wx::WindowUpdateLocker->new( $self->{owner} );
	}
	return;
}

sub update_decrement {
	my $self = shift;
	unless ( --$self->{update_depth} ) {

		# Unlocked for the final time
		$self->{update_locker} = undef;
	}
	return;
}

sub busy_increment {
	my $self = shift;
	unless ( $self->{busy_depth}++ ) {

		# Locking for the first time
		$self->{busy_locker} = Wx::BusyCursor->new;
	}
	return;
}

sub busy_decrement {
	my $self = shift;
	unless ( --$self->{busy_depth} ) {

		# Unlocked for the final time
		$self->{busy_locker} = undef;
	}
	return;
}

sub method_increment {
	$_[0]->{method_depth}++;
	$_[0]->{method_pending}->{$_[1]}++;
	return;
}

sub method_decrement {
	my $self = shift;
	$self->{method_pending}->{$_[0]}--;
	unless ( --$self->{method_depth} ) {
		# Run all of the pending methods
		foreach ( keys %{$self->{method_pending}} ) {
			next if $_ eq uc($_);
			$self->{owner}->$_();
		}
		$self->{method_pending} = {};
	}
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
