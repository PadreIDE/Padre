use strict;
use Padre::DB::Migrate::Patch;

# remove the session table created in migrate-5
do(<<'END_SQL');
DROP TABLE session
END_SQL

# create the new session table
do(<<'END_SQL');
CREATE TABLE session (
	id INTEGER NOT NULL PRIMARY KEY,
	name VARCHAR(255) UNIQUE NOT NULL,
	description VARCHAR(255),
	last_update DATE
)
END_SQL

# create the table containing the session files
do(<<'END_SQL');
CREATE TABLE session_file (
	id INTEGER NOT NULL PRIMARY KEY,
	file VARCHAR(255) NOT NULL,
	position INTEGER NOT NULL,
	focus BOOLEAN NOT NULL,
	session INTEGER NOT NULL,
	FOREIGN KEY (session) REFERENCES session(id)
)
END_SQL
