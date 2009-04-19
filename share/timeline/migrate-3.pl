use strict;
use ORLite::Migrate::Patch;

# Create the host settings table
do(<<'END_SQL');
DROP TABLE modules
END_SQL
