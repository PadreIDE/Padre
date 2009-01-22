package Padre::Config::Human;

# Configuration and state data relating to the human using Padre.

use 5.008;
use strict;
use warnings;
use YAML::Tiny     ();
use Params::Util   qw{_HASH0};
use Padre::Config2 ();

our $VERSION = '0.25';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Check the config

	return $self;
}

sub read {
	my $class = shift;

	# Check the file
	my $file = shift;
	unless ( defined $file and -f $file and -r $file ) {
		return;
	}

	# Load the user configuration
	my $hash = YAML::Tiny::LoadFile($file);
	return unless _HASH0($hash);

	# Create the object
	return $class->new( %$hash );
}

sub write {
	my $self = shift;

	# Clone and remove the bless
	my $copy = Storable::dclone( +{ %$self } );

	# Save the user configuration
	YAML::Tiny::DumpFile( Padre::Config->default_yaml, $copy );

	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
