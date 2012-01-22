package Padre::Test;

# This package should be loaded by your test script (or by -MPadre::Test)
# to signal that Padre is running inside of a test script, and should
# behave appropriately.
#
# To avoid problems with the test environment not matching the run-time
# environment (and as a result missing bugs because the tests don't work
# quite the same as the real thing) uses of this module should be limited
# to highly user-impacting changes, like keeping the Padre window invisible
# during tests.

# In Padre code, the existance of $Padre::Test::VERSION is suitable for
# assuming we are in the test suite.

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.94';

# Disable the splash screen
$ENV{PADRE_NOSPLASH} = 1; ## no critic (RequireLocalizedPunctuationVars)

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
