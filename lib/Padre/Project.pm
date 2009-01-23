package Padre::Project;

# Base project functionality for Padre

use strict;
use warnings;
use File::Spec ();
use YAML::Tiny ();

our $VERSION = '0.26';

use Class::XSAccessor
	getters => {
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
	if ( File::Spec->catfile($root, 'Makefile.PL') ) {
		return 'Padre::Project::Perl';
	}
	if ( File::Spec->catfile($root, 'Build.PL') ) {
		return 'Padre::Project::Perl';
	}
	if ( File::Spec->catfile($root, 'padre.yml') ) {
		return 'Padre::Project';
	}
	return 'Padre::Project::Null';

}





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Check the root directory
	unless ( defined $self->root ) {
		croak("Did not provide a root directory");
	}
	unless ( -d $self->root ) {
		croak("Root directory " . $self->root . " does not exist");
	}

	# Check for a padre.yml file
	my $padre_yml = File::Spec->catfile(
		$self->root,
		'padre.yml',
	);
	if ( -f $padre_yml ) {
		$self->{padre_yml} = YAML::Tiny->read( $padre_yml );
	}

	return $self;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
