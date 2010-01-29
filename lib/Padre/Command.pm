package Padre::Command;

# Padre launches commands on the local operating system in a wide
# variety of different ways, and via different execution channels.
# This class provides a generic abstraction of a command, so that
# commands can be built up in a similar way across all channels, and
# the same command can be run in a variety of different ways if needed.

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.55';





######################################################################
# Constructor and Accessors

# NOTE: Currently, this does no validation
sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	return $self;
}

sub directory {
	$_[0]->{directory};
}

sub program {
	$_[0]->{program};
}

sub parameters {
	$_[0]->{parameters};
}

sub environment {
	$_[0]->{environment};
}

1;
