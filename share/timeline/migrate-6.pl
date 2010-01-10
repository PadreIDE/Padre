use strict;
use Padre::DB::Migrate::Patch;

# Rebuild the config table as not null.

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
