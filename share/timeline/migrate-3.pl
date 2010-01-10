use strict;
use Padre::DB::Migrate::Patch;

# Create the host settings table
do(<<'END_SQL');
DROP TABLE modules
END_SQL
