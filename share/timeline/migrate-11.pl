use strict;
use ORLite::Migrate::Patch;

# Create the recently used table
do(<<'END_SQL');
CREATE TABLE recently_used (
	name        VARCHAR(255) PRIMARY KEY,
	value       VARCHAR(255) NOT NULL,
	type        VARCHAR(255) NOT NULL,
	last_used   DATE         NOT NULL
)
END_SQL