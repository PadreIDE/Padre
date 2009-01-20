package Padre::Config::Host;

# Configuration and state data related to the host that Padre is running on.

use 5.008;
use strict;
use warnings;

# Avoid the introspective compilation until runtime
# use Padre::DB ();

our $VERSION = '0.25';





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
	} Padre::DB::Hostconf->select;

	# Create and return the object
	return $_[0]->new( %hash );
}

sub write {
	require Padre::DB;

	Padre::DB->begin;
	Padre::DB::Hostconf->truncate;
	foreach my $name ( sort keys %{$_[0]} ) {
		Padre::DB::Hostconf->create(
			name  => $name,
			value => undef,
		);
	}
	Padre::DB->commit;

	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
