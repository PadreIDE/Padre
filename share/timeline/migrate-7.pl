use strict;
use warnings;

use File::Spec ();
use lib File::Spec->rel2abs(
	File::Spec->catdir(
		File::Spec->updir,
		File::Spec->updir,
		File::Spec->updir,
		File::Spec->updir,
		File::Spec->updir,
	)
);
use Padre::DB::Patch;


# -- patch content

# add a new table to keep the last position in file
# note: we're not reusing the history table, since history can be truncated.
do(<<'END_SQL');
create table last_position_in_file (
	name varchar(255) not null primary key,
	position integer not null
)
END_SQL

exit(0);
