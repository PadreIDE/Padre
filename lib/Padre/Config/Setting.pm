package Padre::Config::Setting;

# Simple data class for a configuration setting

use 5.008;
use strict;
use warnings;
use Carp            ();
use Params::Util    ();
use Padre::Constant ();

our $VERSION = '0.47';

use Class::XSAccessor getters => {
	name    => 'name',
	type    => 'type',
	store   => 'store',
	default => 'default',
	project => 'project',
	options => 'options',
	apply   => 'apply',
};

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Param checking
	unless ( $self->name ) {
		Carp::croak("Missing or invalid name");
	}
	unless ( _TYPE( $self->type ) ) {
		Carp::croak("Missing or invalid type for setting $self->{name}");
	}
	unless ( _STORE( $self->store ) ) {
		Carp::croak("Missing or invalid store for setting $self->{name}");
	}
	unless ( exists $self->{default} ) {
		Carp::croak("Missing or invalid default for setting $self->{name}");
	}

	# It is illegal to store paths in the human config
	if (    $self->type == Padre::Constant::PATH
		and $self->store == Padre::Constant::HUMAN )
	{
		Carp::croak("PATH values must only be placed in the HOST store");
	}

	# Normalise
	$self->{project} = !!$self->project;

	return $self;
}

#####################################################################
# Support Functions

sub _TYPE {
	return !!( defined $_[0] and not ref $_[0] and $_[0] =~ /^[0-4]\z/ );
}

sub _STORE {
	return !!( defined $_[0] and not ref $_[0] and $_[0] =~ /^[0-2]\z/ );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
