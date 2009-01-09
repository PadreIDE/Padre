use strict;
use warnings;
use Test::More;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

#use Test::NeedsDisplay ':skip_all';
plan skip_all => 'Needs Test::Compile 0.08 but that does not work on Windows' if $^O eq 'MSWin32'; # the same as File::Spec uses
plan skip_all => 'Needs Test::Compile 0.08' if not eval "use Test::Compile 0.08; 1"; ## no critic
diag "Test::Compile $Test::Compile::VERSION";

use File::Temp;
$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
all_pl_files_ok(all_pm_files());
