package main;

use 5.008;
use strict;
use warnings;

package Module;
use strict;
use warnings;
$| = 1;

sub setup {
    my ($class) = @_;
    print join ":", caller();
}



package main;

# use Module;
Module->setup;

print "Your name please:";
my $name = <STDIN>;
chomp $name;
print "Hi $name. How are you?\n";

warn "This is a warning";
