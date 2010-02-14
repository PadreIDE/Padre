#!/usr/bin/perl

# This file assumes that you already read (and understood) earlier sessions!

use strict;
use warnings;

# Our last salat saved typing but it didn't save source code lines. We'll try
# to change this now by combining two things we know.

# Let's start again with our Add-items-sub. I'ld like to Add many things
# using one sub-call like this

# add "salt","pepper","dressing";

# To start a sub, we still need to tell Perl that the following is a sub
# and how it's called

sub add {

	# The first argument is $_[0], so it should be a good idea to place the 0
	# somewhere

	my $argument_number = 0;

	# Let's just try out something. We got $_[0] and a variable containing a 0,
	# should it be possible to combine them by replacing the fixed 0 by the
	# variable name?

	print $_[$argument_number] . "\n";

	# This should print out the first argument and if you try it out, you'll get
	# the expected salt.

}

add "salt", "pepper", "dressing";

# Want to try out if this works for the second and third argument? Do it, the
# more you try, the more you learn!

# You remember that each sub name may only be used once, so I'll call the next
# example sub by another name and for matching the output text to the source
# code, I'll add prints sepeating each try:

print "--- Try #2 ---\n";

sub add2 {

	# How do we get the sub to walk through the numbers 0 to 2 to get all arguments?
	# Sounds like a job for a loop and I'll start with a for try

	foreach my $argument_number ( 0 .. 2 ) {
		print $_[$argument_number] . "\n";
	}
}

# We need to call a sub to use it, otherwise the source code won't be executed:

add2 "salt", "pepper", "dressing";

# I'm sure that you'll figure out how to insert the "Add some" into the sub above.

# But what if we like nuts and also want to add them? 0..2 won't show them as the
# nuts are the fourths argument and got number #3.

print "--- Try #3 ---\n";

# I know, how many things I'ld like to add, so I could tell it to the sub:

# add3 4,"salt","pepper","dressing","nuts";

# Getting the 4 is easy - it became the first argument and the first argument
# is always called $_[0]

sub add3 {

	my $number_of_items = $_[0];

	# There is another place where we got numbers and didn't try to replace them by
	# variables until now, but this can't wait any longer

	foreach my $argument_number ( 0 .. $number_of_items ) {

		# The number of the first argument is fixed, so there is no need to push it
		# into a variable and use it only once. It could stay fixed within the for
		# line. There is nothing new following now:

		print $_[$argument_number] . "\n";
	}
}

add3 4, "salt", "pepper", "dressing", "nuts";

# You may notice that the first line contains the number of items to add, the 4
# We don't want this, so you should try to change the above sample to skip the
# first argument and start with the second one (numbered 1).

print "--- Try #4 ---\n";

# Our add-item-sub seems to work, so I'll copy it for cutting stripes and pieces:

sub cut_stripes {

	my $number_of_items = $_[0];

	foreach my $argument_number ( 1 .. $number_of_items ) {
		print "Cut " . $_[$argument_number] . " in stripes\n";
	}
}

sub cut_pieces {

	my $number_of_items = $_[0];

	foreach my $argument_number ( 1 .. $number_of_items ) {
		print "Cut " . $_[$argument_number] . " in pieces\n";
	}
}

print "Ordered salat:\n";
cut_stripes 2, "green salat", "a paprika";
cut_pieces 2,  "a tomato",    "half of a cucumber";
add3 1,        "nuts";
print "Mix everything\n";
add3 3, "dressing", "salt", "pepper";
cut_stripes 1, "a chicken breast";
print "Roast the chicken breast stripes\n";
print "Put them over the salat\n";

# We're done! Now go to the kittchen and enjoy our salat or just continue if
# you don't need a break.

# I don't like duplicate code like the one we used in the cut_stripes and
# cut_pieces. It differs only by one word - the cutting style but if you got
# two subs which 100 lines each and they differ by only one or two lines,
# it's even worse. I have seen such code much more often than I'ld like and
# you think.
# Your job: Merge them to one sub! I'll guide you through three ways to do
# this.

# --- First way ---

# You should print a seperator line like the "--- Try ---" - lines before to
# clearly see what comes from your source.

# Next, please add a sub which gets one item and the cutting style as arguments
# Sounds like you could copy something we did earlier...

# Now just copy the two subs for stripes and pieces and make them call the sub
# you added instead of using print.

# --- Second way ---

# Remember: A seperator here would help.

# We're passing the number of items to the add- and cut-subs, why not also pass
# the cutting style to the cut-sub. Create a copy and get the number of items
# and the cutting style from the arguments before start reading the items.

# A sample call could be: cut "stripes",2,"green salat", "a paprika";

# Things will be easier if you get a visual picture of what the arguments.
# Write down a list containing the number and value of each argument.

# I'ld accept if you need to supply another number than the count of items
# for the first try of your sub. But for the final solution, it's a bad way
# if someone else needs to use your subs, so you should take care of this
# yourself within your sub.

# --- Third way ---

# If you finished everything until now, you're done with this file. The last
# part is really optional and you don't need to worry if you don't solve it.

# Given the following source code
#print "Ordered salat:\n";
#cut 4,
#	"green salat",		"stripes",
#	"a paprika",		"stripes",
#	"a tomato",		"pieces",
#	"half of a cucumber",	"pieces");
#add 1,"nuts";
#print "Mix everything\n";
#add 3,"dressing","salt","pepper";
#cut 1,"a chicken breast","stripes";
#print "Roast the chicken breast stripes\n";
#print "Put them over the salat\n";

# Select the whole block (from cut 4, to the last print) and press Ctrl-Alt-C
# or click on the green # sign on the toolbar to remove the # comment signs
# from each line.

# This is a really hard challenge, because you need to plan your solution
# yourself and make source code from it.

# If you don't know how to start, try the following:
# I think, we agree that you need to make a sub for the cut-items. So write
# the sub name { line and the } in the next line.
# Now insert comment lines (like this one) between the { }. Try to make one
# comment for each step you need to do. Then go through your lines and split
# them by exchanging one line for two or more new ones where the new ones
# do a part of the combined line.
# Once you're happy with the result, try to write the source code line below
# each comment line. Each comment should be followed by at least one source
# code line doing what the comment did.
# You'll notice that you need to change your solution (and the comments) maybe
# multiple times. Don't worry, this is typical. A program devlops while you
# write it, even for the best and most detailed plans.
