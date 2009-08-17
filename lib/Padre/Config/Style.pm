package Padre::Config::Style;

# Interface to the Padre editor look and feel files

use 5.008;
use strict;
use warnings;
use Carp ();
use Params::Util qw{ _IDENTIFIER _HASH };
use YAML::Tiny ();

our $VERSION = '0.43';

######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	unless ( _IDENTIFIER( $self->name ) ) {
		Carp::croak("Missing or invalid style name");
	}
	unless ( _HASH( $self->data ) ) {
		Carp::croak("Missing or invalid style data");
	}
	return $self;
}

sub load {
	my $class = shift;
	my $name  = shift;
	my $file  = shift;
	unless ( -f $file ) {
		Carp::croak("Missing or invalid file name");
	}

	# Load the YAML file
	my $data = eval { YAML::Tiny::LoadFile($file); };
	if ($@) {
		warn $@;
		return undef;
	}

	# Create the style
	$class->new(
		name => $name,
		data => $data,
	);
}

sub name {
	$_[0]->{name};
}

sub data {
	$_[0]->{data};
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
