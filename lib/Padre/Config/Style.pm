package Padre::Config::Style;

# Interface to the Padre editor look and feel files

use 5.008;
use strict;
use warnings;
use Carp            ();
use File::Spec      ();
use File::Glob      ();
use File::Basename  ();
use Params::Util    ();
use Padre::Constant ();
use Padre::Util     ('_T');

our $VERSION = '0.68';





######################################################################
# Style Library

# Define the core style library
our %CORE_STYLES = (
	default   => _T('Padre'),
	evening   => _T('Evening'),
	night     => _T('Night'),
	ultraedit => _T('Ultraedit'),
	notepad   => _T('Notepad++'),
);

# Locate any custom user styles
our $USER_DIRECTORY = File::Spec->catdir( Padre::Constant::CONFIG_DIR, 'styles' );
our @USER_STYLES =
	map { substr( File::Basename::basename($_), 0, -4 ) }
	File::Glob::glob( File::Spec->catdir( $USER_DIRECTORY, '*.yml' ) );

sub core_styles {
	return %CORE_STYLES;
}

sub user_styles {
	return @USER_STYLES;
}





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	unless ( Params::Util::_IDENTIFIER( $self->name ) ) {
		Carp::croak("Missing or invalid style name");
	}
	unless ( Params::Util::_HASH( $self->data ) ) {
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
	my $data = eval {
		require YAML::Tiny;
		YAML::Tiny::LoadFile($file);
	};
	if ($@) {
		warn $@;
		return;
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

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
