package Padre::Project;

# Base project functionality for Padre

use 5.008;
use strict;
use warnings;
use File::Spec    ();
use YAML::Tiny    ();
use Padre::Config ();

our $VERSION = '0.41';

use Class::XSAccessor getters => {
	root      => 'root',
	padre_yml => 'padre_yml',
};

######################################################################
# Class Methods

sub class {
	my $class = shift;
	my $root  = shift;
	unless ( -d $root ) {
		Carp::croak("Project directory '$root' does not exist");
	}
	if ( -f File::Spec->catfile( $root, 'Makefile.PL' ) ) {
		return 'Padre::Project::Perl';
	}
	if ( -f File::Spec->catfile( $root, 'Build.PL' ) ) {
		return 'Padre::Project::Perl';
	}
	if ( -f File::Spec->catfile( $root, 'dist.ini' ) ) {
		return 'Padre::Project::Perl';
	}
	if ( -f File::Spec->catfile( $root, 'padre.yml' ) ) {
		return 'Padre::Project';
	}
	return 'Padre::Project::Null';

}

######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Check the root directory
	unless ( defined $self->root ) {
		croak("Did not provide a root directory");
	}
	unless ( -d $self->root ) {
		croak( "Root directory " . $self->root . " does not exist" );
	}

	# Check for a padre.yml file
	my $padre_yml = File::Spec->catfile(
		$self->root,
		'padre.yml',
	);
	if ( -f $padre_yml ) {
		$self->{padre_yml} = $padre_yml;
	}

	return $self;
}

sub config {
	my $self = shift;
	unless ( $self->{config} ) {

		# Get the default config object
		my $config = Padre->ide->config;

		# If we have a padre.yml file create a custom config object
		if ( $self->{padre_yml} ) {
			require Padre::Config::Project;
			$self->{config} = Padre::Config->new(
				$config->host,
				$config->human,
				Padre::Config::Project->read(
					$self->{padre_yml},
				),
			);
		} else {
			$self->{config} = Padre::Config->new(
				$config->host,
				$config->human,
			);
		}
	}
	return $self->{config};
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
