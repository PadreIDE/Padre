package Padre::Config::Host;

# Configuration and state data related to the host that Padre is running on.

use 5.008;
use strict;
use warnings;

# Avoid the introspective compilation until runtime
# use Padre::DB ();

our $VERSION = '0.27';





#####################################################################
# Constructor and Storage Interaction

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	return $self;
}

# Read config from the database (overwriting any existing data)
sub read {
	require Padre::DB;

	# Read in the config data
	my %hash = map {
		$_->name => $_->value
	} Padre::DB::HostConfig->select;

	# Create and return the object
	return $_[0]->new( %hash );
}

sub write {
	require Padre::DB;

	my $self = shift;
	Padre::DB->begin;
	Padre::DB::HostConfig->truncate;
	foreach my $name ( sort keys %$self ) {
		Padre::DB::HostConfig->create(
			name  => $name,
			value => $self->{$name},
		);
	}
	Padre::DB->commit;

	return 1;
}

sub version {
	$_[0]->{version};
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
