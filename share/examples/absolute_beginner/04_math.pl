#!/usr/bin/perl

# This file assumes that you already read (and understood) earlier sessions!

use strict;

# Before starting the actual topic of this lesson, lets do a short stop at
# use strict; which you saw in the last files: If you write this at the
# beginning, you need to write a "my" before the variable name when you
# first mention a variable in your script. Sounds complicated, but makes
# things much easier if get a typo. If you accidently type $hor instead
# of $hour and use strict; is in place, Perl will warn you about this typo.

use warnings;

# A good amount of programming is more or less simple math. Perl could do this
# as you could see on the following complex calculation:

my $sum = 1 + 1;
print "$sum\n";

# You learned something about mathematical brackets and preference rules,
# did you? Perl respects them all:

my $result = ( ( 10 * 2 + 1 ) - ( 2 + 5 ) ) / 2;
print "$result\n";

# Not to forget, there is no need to use a variable for this:

print "Simple math result: " . ( 1 + 2 + 3 ) . "\n";

# Cool, isn't it?
# Oh, this is a new print syntax we got. Lets look at it in three parts:
#  (1 + 2 + 3) is just a calculation like the others before.
#              It's not written in ", because it's no text. Try youself
#              what happens if you put " around it.
#  .           Here is the special magic of this command: A single dot
#              between two items concates them.
#  "\n";       You should know this already.
#
# Items in this case could be many things, for example:
#  - Text blocks surrounded by "
#  - Calculations in brackets ( )
#  - Variables

# Calculations may also include variables:

print "$sum + 1 is " . ( $sum + 1 ) . "\n";

# We could mix some things we used earlier:

print "$sum + $result = " . ( $sum + $result ) . "\n";

# One of the most used commands in programming is a simple increment:

$sum = $sum + 1;

# This adds 1 to $sum, but Perl allows you to make things much easier:

++$sum; # Excatly the same as $sum = $sum + 1;

# Another syntax which is valid for all four simple calculations + - * /

$sum += 2; # Same as $sum = $sum + 2;
print $sum. "\n";

# Now press F5 and Padre will execute this script.
#
# You'll see a new window on the bottom of Padre which shows you the
# output of this script.

# Here is enough space for you to try out some math. You should try at least
# the four + - * / operators once and once combined with a =. Add additional
# lines as needed:
