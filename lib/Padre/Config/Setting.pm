package Padre::Config::Setting;

# Simple data class for a configuration setting

use 5.008;
use strict;
use warnings;

use Carp                     ();
use Padre::Config::Constants qw{ :stores :types };
use Params::Util             ();

our $VERSION = '0.29';

use Class::XSAccessor
	getters => {
		name    => 'name',
		type    => 'type',
		store   => 'store',
		default => 'default',
	};

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Param checking
	unless ( $self->name ) {
		Carp::croak("Missing or invalid name");
	}
	unless ( _ISTYPE($self->type) ) {
		Carp::croak("Missing or invalid type for setting $self->{name}");
	}
	unless ( _ISSTORE($self->store) ) {
		Carp::croak("Missing or invalid store for setting $self->{name}");
	}
	unless ( exists $self->{default} ) {
		Carp::croak("Missing or invalid default for setting $self->{name}");
	}

	return $self;
}





#####################################################################
# Support Functions

sub _ISTYPE {
	return !! (
		defined $_[0]
		and
		not ref $_[0]
		and {
			0 => 1,
			1 => 1,
			2 => 1,
			3 => 1,
		}->{$_[0]}
	);
}

sub _ISSTORE {
	return !! (
		defined $_[0]
		and
		not ref $_[0]
		and {
			0 => 1,
			1 => 1,
			2 => 1,
		}->{$_[0]}
	);
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
