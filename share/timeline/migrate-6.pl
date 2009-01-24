#!/usr/bin/perl

# Rebuild the config table as not null.

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

# This should get rid of the old config settings :)
do(<<'END_SQL');
drop table hostconf
END_SQL

# Since we have to create a new version, use a slightly better table name
do(<<'END_SQL');
create table host_config (
	name varchar(255) not null primary key,
	value varchar(255) not null
)
END_SQL

exit(0);
