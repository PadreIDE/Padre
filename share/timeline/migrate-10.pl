use strict;
use Padre::DB::Migrate::Patch;

# We now use classes as names

do( "UPDATE plugin SET name = 'Padre::Plugin::' || name"    );
do( "DELETE FROM plugin WHERE name LIKE 'Padre::Plugin::%'" );
