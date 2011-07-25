package Padre::DB::Migrate::Patch6;

use strict;
use warnings;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.85';
our @ISA     = 'Padre::DB::Migrate::Patch';





######################################################################
# Migrate Forwards

sub upgrade {
	my $self = shift;

	# This should get rid of the old config settings :)
	$self->do('DROP TABLE hostconf');

	# Since we have to create a new version, use a slightly better table name
	$self->do(<<'END_SQL');
CREATE TABLE host_config (
	name VARCHAR(255) NOT NULL PRIMARY KEY,
	value VARCHAR(255) NOT NULL
)
END_SQL

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

