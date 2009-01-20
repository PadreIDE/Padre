package Padre::Config::Setting;

# Simple data class for a configuration setting

use 5.008;
use strict;
use warnings;
use Carp         ();
use Params::Util ();

our $VERSION = '0.25';

# TODO: Really shouldn't clone these constants,
# but for now it's a nice convenience.

# Settings Types
use constant BOOLEAN => 0;
use constant INTEGER => 1;
use constant STRING  => 2;
use constant PATH    => 3;

# Setting Stores
use constant HOST    => 0;
use constant HUMAN   => 1;
use constant PROJECT => 2;

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

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
