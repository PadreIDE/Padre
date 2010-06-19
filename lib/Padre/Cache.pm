package Padre::Cache;

# Lightweight in-memory caching mechanism primarily intended for
# storing GUI model data keyed against projects or documents.

use 5.008;
use strict;
use warnings;
use Params::Util ();

our $VERSION = '0.64';

my %DATA = ();

sub stash {
	my $owner = shift;
	my $key   = key(shift);
	$DATA{$key}->{$owner} or
	$DATA{$key}->{$owner} = {};
}

sub release {
	my $owner = shift;
	my $key   = key(shift);
	delete $DATA{$key};
	return 1;
}

sub key {
	if ( Params::Util::_INSTANCE($_[0], 'Padre::Project') ) {
		return shift->root;
	}
	if ( Params::Util::_INSTANCE($_[0], 'Padre::Document') ) {
		return shift->filename;
	}
	return shift;
}

1;
