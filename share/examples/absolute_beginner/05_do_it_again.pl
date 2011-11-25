#!/usr/bin/perl

# This file assumes that you already read (and understood) earlier sessions!

use strict;
use warnings;

# Let's say you want to count from 1 to 10. Pretty easy, just write:
my $counter = 0;
$counter++;
print "$counter\n";
$counter++;
print "$counter\n";
$counter++;
print "$counter\n";
$counter++;
print "$counter\n";
$counter++;
print "$counter\n";
$counter++;
print "$counter\n";
$counter++;
print "$counter\n";
$counter++;
print "$counter\n";
$counter++;
print "$counter\n";
$counter++;
print "$counter - done!\n";

# Works perfectly, but there are some drawbacks:
#  - It takes 21 lines (imagine you want to count until 100!)
#  - What happens if you need to change $counter to $counter2?

print "--- next sample ---\n";

# Every time you copy/paste a line of sourcecode, stop a moment and think
# about looping. This means, let Perl repeat some lines for you:

my $loop_counter = 0;
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
	# sourcecode as separate lines. Perl dosn't care, but you and others need to
	# be able to read it without scrolling thousend columns to the right.

	# It might look like a waste of time, but if you put spaces or tabs before each
	# line within a if/loop/block, your source will be much more readable. Start
	# now and you're used to do it in a few days and it will save you very much
	# time hunting for lines in the wrong block lateron. Perl masters always do it.

	++$loop_counter;
	print "$loop_counter\n";

}

# If you ignore my big boring comments above, this loop does the same in only 5
# lines what we did earlier in 21 lines and you got three places left where you
# need to change the variable name if you're forced to.

print "--- next sample ---\n";

# Perl could also be used for cooking:

foreach my $fruit ( "Orange", "Apple", "Strawberry", "Melon", "Lemon" ) {
	print "1 $fruit\n";
}
print "Cut the fruits in not-too-small pieces and your fruitsalat is done.\n";

# If you add a variable just behind "for", this variable will have the item for
# the current loop run. The salat example just prints the $Fruit, but you could
# do much more inside the loop.

print "--- next sample ---\n";

# "for" - loops got one drawback: You need to know how many times your loop
# should run before the loop starts and sometimes you don't know this.

# This sample tries to find out how often a given number (for example 123)
# could be divided by 2 before it gets lower than two.

my $number    = 123;
my $two_count = 0;

# Two variables, one holding the number and the second for the number of times
# we divided the number.

while ( $number > 2 ) {

	# while loops run until the condition (which is the same we used for the if's)
	# is no longer true. $number is 123 at the first run which is greater than 2
	# and the following lines are executed.

	print "$number\n";
	$number /= 2; # Look at the math session to understand this.
	++$two_count;
}

print "Divided $two_count times\n";

# Always beware of endless loops where the condition always stays true! Your
# program would never leave the loop.

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
