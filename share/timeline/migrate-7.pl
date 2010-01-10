use strict;
use Padre::DB::Migrate::Patch;

# add a new table to keep the last position in file
# note: we're not reusing the history table, since history can be truncated.
do(<<'END_SQL');
create table last_position_in_file (
	name varchar(255) not null primary key,
	position integer not null
)
END_SQL
