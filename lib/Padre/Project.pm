package Padre::Project;

# Base project functionality for Padre

use strict;
use warnings;
use File::Spec ();
use YAML::Tiny ();

our $VERSION = '0.21';





######################################################################
# Class Methods

sub project_class {
	my $class = shift;
	my $dir   = shift;
	unless ( -d $dir ) {
		die("Directory '$dir' does not exist");
	}

	
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

sub root {
	$_[0]->{root}
}

sub padre_yml {
	$_[0]->{padre_yml}
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
