# This test handels incomplete sourcecode parts of Padre.
# Padre might be critical unstable, crashy or do bad things if this test is failing!

use Test::More tests => 1;

use File::Slurp;

# A Padre::TaskHandle->on_finish method is called somewhere, which is good, but
# it's unknown what on_finish should so. Remove this test if on_finish wasn't
# expected to be more than the given sample.
unlike(
	read_file('lib/Padre/TaskHandle.pm'), qr/sub\s*on_finish\s*\{\s*\}/,
	'Padre::TaskHandle has empty on_finish method'
);

unlike(
	read_file('lib/Padre/Task.pm'), qr/sub\s*owner\s*\{\s*\}/,
	'Padre::Task has empty owner method'
);
