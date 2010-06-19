package Padre::Cache;

# Lightweight in-memory caching mechanism primarily intended for
# storing GUI model data keyed against projects or documents.

use 5.008;
use strict;
use warnings;

our $VERSION = '0.64';

# Cache data storage
my %PROJECT  = ();
my %DOCUMENT = ();

sub stash {
	my $owner = shift;
	my $key   = shift;

	if ( $key->isa('Padre::Project') ) {
		my $id = $key->root;
		return (
			$PROJECT{$id}->{$owner} or
			$PROJECT{$id}->{$owner} = { }
		);

	} elsif ( $key->isa('Padre::Document') ) {
		my $id = $key->filename;
		return (
			$DOCUMENT{$id}->{$owner} or
			$DOCUMENT{$id}->{$owner} = { }
		);

	} else {
		die 'Missing or invalid key for Padre::Cache';
	}
}

sub release {
	my $owner = shift;
	my $key   = shift;

	if ( $key->isa('Padre::Project') ) {
		delete $PROJECT{$key->root};

	} elsif ( $key->isa('Padre::Document') ) {
		delete $DOCUMENT{$key->filename};

	} else {
		die 'Missing or invalid key for Padre::Cache';
	}

	return 1;
}

1;
