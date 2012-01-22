package Padre::Config::Project;

# Configuration and state data that describes project policies.

use 5.008;
use strict;
use warnings;
use Scalar::Util   ();
use File::Basename ();
use YAML::Tiny     ();
use Params::Util   ();

our $VERSION = '0.94';





######################################################################
# Constructor

sub new {
	my $class = shift;
	bless { @_ }, $class;
}

sub dirname {
	$_[0]->{dirname};
}

sub fullname {
	$_[0]->{fullname};
}

sub read {
	my $class = shift;

	# Check the file
	my $fullname = shift;
	unless ( defined $fullname and -f $fullname and -r $fullname ) {
		return;
	}

	# Load the user configuration
	my $hash = YAML::Tiny::LoadFile($fullname);
	return unless Params::Util::_HASH0($hash);

	# Create the object, saving the file name and directory for later usage
	return $class->new(
		%$hash,
		fullname => $fullname,
		dirname  => File::Basename::dirname($fullname),
	);
}

#
# my $new = $config->clone;
#
sub clone {
	my $self  = shift;
	my $class = Scalar::Util::blessed($self);
	return $class->new(%$self);
}

# NOTE: Once we add the ability to edit the project settings, make sure
# we strip out the path value before we save them.

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
