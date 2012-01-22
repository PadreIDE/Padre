package Padre::Cache;

# Lightweight in-memory caching mechanism primarily intended for
# storing GUI model data keyed against projects or documents.

use 5.008;
use strict;
use warnings;
use Params::Util ();

our $VERSION = '0.94';

my %DATA = ();

sub stash {
	my $class = shift;
	my $owner = shift;
	my $key   = shift;

	# We need an instantiated cache target
	# NOTE: The defined is needed because Padre::Project::Null
	# boolifies to false. In retrospect, that may have been a bad idea.
	if ( defined Params::Util::_INSTANCE( $key, 'Padre::Project' ) ) {
		$key = $key->root;
	} elsif ( Params::Util::_INSTANCE( $key, 'Padre::Document' ) ) {
		$key = $key->filename;
	} else {
		die "Missing or invalid cache key";
	}

	$DATA{$key}->{$owner}
		or $DATA{$key}->{$owner} = {};
}

sub release {
	delete $DATA{ $_[1] };
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
