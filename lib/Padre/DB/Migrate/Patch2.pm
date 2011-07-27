package Padre::DB::Migrate::Patch2;

# This patch creates the plugin table.
# In the initial implementation this stores the enabled/disabled
# state of the plugin, the version, and the config structure for
# the plugin.

use 5.008;
use strict;
use warnings;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.89';
our @ISA     = 'Padre::DB::Migrate::Patch';





######################################################################
# Migrate Forwards

sub upgrade {
	my $self = shift;

	# Create the host settings table
	$self->do(<<'END_SQL');
CREATE TABLE plugin (
	name VARCHAR(255) PRIMARY KEY,
	version VARCHAR(255),
	enabled BOOLEAN,
	config TEXT
)
END_SQL

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

