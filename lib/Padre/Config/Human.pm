package Padre::Config::Human;

# Configuration and state data relating to the human using Padre.

use 5.008;
use strict;
use warnings;
use Storable      ();
use YAML::Tiny    ();
use Params::Util  qw{_HASH0};
use Padre::Config ();

our $VERSION = '0.25';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	return $self;
}

sub read {
	my $class = shift;

	# Load the user configuration
	my $hash = eval {
		YAML::Tiny::LoadFile(
			Padre::Config->default_yaml
		)
	};
	return unless _HASH0($hash);

	# Create the object
	return $class->new( %$hash );
}

sub create {
	my $class = shift;
	my $file  = Padre::Config->default_yaml;

	YAML::Tiny::DumpFile( $file, {
		version => 1,
	} ) or Carp::croak("Failed to create '$file'");

	return $class->read( $file );
}

sub write {
	my $self = shift;

	# Clone and remove the bless
	my $copy = Storable::dclone( +{ %$self } );

	# Save the user configuration
	YAML::Tiny::DumpFile(
		Padre::Config->default_yaml,
		$copy,
	);

	return 1;
}

sub version {
	$_[0]->{version};
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
