use strict;
use Padre::DB::Migrate::Patch;

# Create the syntax highlighter table
do(<<'END_SQL');
CREATE TABLE syntax_highlight (
	mime_type VARCHAR(255) PRIMARY KEY,
	value VARCHAR(255)
)
END_SQL

