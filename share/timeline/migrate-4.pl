#!/usr/bin/perl

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

# Create the bookmark table
do(<<'END_SQL');
CREATE TABLE bookmark (
	name VARCHAR(255) NOT NULL PRIMARY KEY,
	file VARCHAR(255) NOT NULL,
	line INTEGER NOT NULL
)
END_SQL

exit(0);
