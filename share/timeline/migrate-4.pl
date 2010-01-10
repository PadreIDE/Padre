use strict;
use Padre::DB::Migrate::Patch;

# Create the bookmark table
do(<<'END_SQL');
CREATE TABLE bookmark (
	id   INTEGER NOT NULL PRIMARY KEY,
	name VARCHAR(255) UNIQUE NOT NULL,
	file VARCHAR(255) NOT NULL,
	line INTEGER NOT NULL
)
END_SQL
