use strict;
use Padre::DB::Migrate::Patch;

# create the session table
do(<<'END_SQL');
CREATE TABLE session (
	id INTEGER NOT NULL PRIMARY KEY,
	file VARCHAR(255) UNIQUE NOT NULL,
	line INTEGER NOT NULL,
	character INTEGER NOT NULL,
	clue VARCHAR(255),
	focus BOOLEAN NOT NULL
)
END_SQL
