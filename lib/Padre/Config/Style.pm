package Padre::Config::Style;

# Interface to the Padre editor look and feel files.
# Note, this module deals only with the style configuration files,
# it does not attempt style compilation or any form of integration
# with the Wx modules.

use 5.008;
use strict;
use warnings;
use Carp            ();
use File::Spec      ();
use File::Basename  ();
use Params::Util    ();
use Padre::Constant ();
use Padre::Util     ('_T');
use Padre::Logger;

our $VERSION    = '0.90';
our $COMPATIBLE = '0.79';





######################################################################
# Style Library

use vars qw{
	%CORE_STYLES $CORE_DIRECTORY
	@USER_STYLES $USER_DIRECTORY
	%STYLES
};

BEGIN {

	# The location of the style files
	$CORE_DIRECTORY = Padre::Util::sharedir('styles');
	$USER_DIRECTORY = File::Spec->catdir(
		Padre::Constant::CONFIG_DIR,
		'styles',
	);

	# Define the core style library
	%CORE_STYLES = (
		default       => _T('Padre'),
		evening       => _T('Evening'),
		night         => _T('Night'),
		ultraedit     => _T('Ultraedit'),
		notepad       => _T('Notepad++'),
		solarize_dark => _T('Solarize') . ' ' . _T('Dark'),
	);

	# Locate any custom user styles
	@USER_STYLES = ();
	if ( -d $USER_DIRECTORY ) {
		local *STYLEDIR;
		opendir( STYLEDIR, $USER_DIRECTORY ) or die "Failed to read '$USER_DIRECTORY'";
		@USER_STYLES =
			sort grep { defined Params::Util::_IDENTIFIER($_) }
			map { substr( File::Basename::basename($_), 0, -4 ) } grep {/\.yml$/} readdir STYLEDIR;
		closedir STYLEDIR;
	}

	# Build the second-generation config objects
	%STYLES = ();

	# You don't have your own ->new in the BEGIN block
	# before you declare it
	#	foreach my $name ( sort keys %CORE_STYLES ) {
	#		$STYLES{$name} = Padre::Config::Style->new(
	#			name    => $name,
	#			label   => $CORE_STYLES{$name},
	#			private => 0,
	#			file    => File::Spec->catfile(
	#				$CORE_DIRECTORY, "$name.yml",
	#			),
	#		);
	#	}
	#	foreach my $name ( @USER_STYLES ) {
	#		$STYLES{$name} = Padre::Config::Style->new(
	#			name    => $name,
	#			label   => $name,
	#			private => 1,
	#			file    => File::Spec->catfile(
	#				$USER_DIRECTORY, "$name.yml",
	#			),
	#		);
	#	}
}

# Convenience access to the merged style list
sub styles {
	return {
		%CORE_STYLES,
		map { $_ => $_ } @USER_STYLES,
	};
}

sub core_styles {
	return \%CORE_STYLES;
}

sub user_styles {
	return { map { $_ => $_ } @USER_STYLES };
}





######################################################################
# Constructor

sub new {
	TRACE( $_[0] ) if DEBUG;
	my $class = shift;
	bless {@_}, $class;
}

sub load {
	TRACE( $_[0] ) if DEBUG;
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

sub label {
	$_[0]->{label};
}

sub private {
	$_[0]->{private};
}

sub file {
	$_[0]->{file};
}

sub data {
	$_[0]->{data}
		or $_[0]->{data} = $_[0]->read;
}

sub read {
	my $self = shift;
	my $file = $self->file;
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

}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
