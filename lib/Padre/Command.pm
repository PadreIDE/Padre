package Padre::Command;

# Padre launches commands on the local operating system in a wide
# variety of different ways, and via different execution channels.
# This class provides a generic abstraction of a command, so that
# commands can be built up in a similar way across all channels, and
# the same command can be run in a variety of different ways if needed.

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.94';

use Class::XSAccessor {
	getters => {

		# The fully resolved path to the program to execute
		program => 'program',

		# Parameters to the command as an ARRAY reference
		parameters => 'parameters',

		# Where to set the directory when starting the command
		directory => 'directory',

		# Differences to the environment while running the command
		environment => 'environment',

		# Should the command be run in a visible shell
		visible => 'visible',
	},
};





######################################################################
# Constructor and Accessors

# NOTE: Currently, this does no validation
sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Defaults
	unless ( defined $self->{parameters} ) {
		$self->{parameters} = [];
	}
	unless ( defined $self->{directory} ) {
		require File::HomeDir;
		$self->{directory} = File::HomeDir->my_home;
	}
	unless ( defined $self->{environment} ) {
		$self->{environment} = {};
	}
	unless ( defined $self->{visible} ) {
		$self->{visible} = 0;
	}

	return $self;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
