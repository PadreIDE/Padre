#!/usr/bin/perl

# This file assumes that you already read (and understood) earlier sessions!

use strict;
use warnings;

# Let's say you want to count from 1 to 10. Pretty easy, just write:
my $Counter = 0;
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter\n";
$Counter++;
print "$Counter - done!\n";

# Works perfectly, but there are some drawbacks:
#  - It takes 21 lines (imagine you want to count until 100!)
#  - What happens if you need to change $Counter to $Counter2?

print "--- next sample ---\n";

# Every time you copy/paste a line of sourcecode, stop a moment and think
# about looping. This means, let Perl repeat some lines for you:

my $LoopCounter = 0;
for ( 1 .. 10 ) {

	# "for" is a special keyword which says Perl: "I'll give you a list of items
	# and for each item, please execute the following sourcecode once."
	# Sounds much more complicated than it acutally is.
	# (1..10) is a range: It has a starting number (1) and a final value (10)
	# and Perl should give you all numbers from 1 to 10.
	# The lines which belong to this "for" - loop are between the same brackets { }
	# you already know from if. Actually every logical block of sourcecode is
	# surrounded by them.

	# If you write more than one line of sourcecode between { and }, write this
	# sourcecode as seperate lines. Perl dosn't care, but you and others need to
	# be able to read it without scrolling thousend columns to the right.

	# It might look like a waste of time, but if you put spaces or tabs before each
	# line within a if/loop/block, your source will be much more readable. Start
	# now and you're used to do it in a few days and it will save you very much
	# time hunting for lines in the wrong block lateron. Perl masters always do it.

	++$LoopCounter;
	print "$LoopCounter\n";

}

# If you ignore my big boring comments above, this loop does the same in only 5
# lines what we did earlier in 21 lines and you got three places left where you
# need to change the variable name if you're forced to.

print "--- next sample ---\n";

# Perl could also be used for cooking:

for my $Fruit ( "Orange", "Apple", "Strawberry", "Melon", "Lemon" ) {
	print "1 $Fruit\n";
}
print "Cut the fruits in not-too-small pieces and your fruitsalat is done.\n";

# If you add a variable just behind "for", this variable will have the item for
# the current loop run. The salat example just prints the $Fruit, but you could
# do much more inside the loop.

print "--- next sample ---\n";

# "for" - loops got one drawback: You need to know how many times your loop
# should run before the loop starts and sometimes you don't know this.

my $Number   = 123;
my $TwoCount = 0;
while ( $Number > 2 ) {
	print "$Number\n";
	$Number /= 2;
	++$TwoCount;
}
print "$Number\n";
print "2^$TwoCount\n";

# This is a combination of an if and a loop: while the condition is true, the
# loop is repeated. Always beware of endless loops where the condition always
# stays true! Your program would never leave the loop.

# Now press F5 and Padre will execute this script.
#
# You'll see a new window on the bottom of Padre which shows you the
# output of this script.
# We have a lot of samples with a lot of output in this file, so first try to
# match each block of output to the correct source code sample and try to
# understand what happens. Play around with the source if you want and change
# things to get other results.

# If you understood this lesson, this is easy for you:
# Try to write a loop which shows all even numbers from 20 to 30.
# Hint: Remember that 10 * 2 is 20 and 11 * 2 is 22.

# Got it working? Congratulations!
# Next, try to do the same using a while loop instead of for.
