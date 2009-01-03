#!/usr/bin/perl

# This patch creates the plugin table.
# In the initial implementation this stores the enabled/disabled
# state of the plugin, the version, and the config structure for
# the plugin.

use strict;
use File::Spec ();
use lib File::Spec->rel2abs(
	File::Spec->catdir(
		File::Spec->updir,
		File::Spec->updir,
		File::Spec->updir,
		File::Spec->updir,
		File::Spec->updir,
	)
);
use Padre::DB::Patch;





#####################################################################
# Patch Content

# Create the host settings table
do(<<'END_SQL');
CREATE TABLE plugin (
	name VARCHAR(255) PRIMARY KEY,
	version VARCHAR(255),
	enabled BOOLEAN,
	config TEXT
)
END_SQL

exit(0);
