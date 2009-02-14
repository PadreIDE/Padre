# This patch removes the old modules table.

use strict;
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





#####################################################################
# Patch Content

# Create the host settings table
do(<<'END_SQL');
DROP TABLE modules
END_SQL

exit(0);
