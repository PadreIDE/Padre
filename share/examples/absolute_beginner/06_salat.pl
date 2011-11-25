#!/usr/bin/perl

# This file assumes that you already read (and understood) earlier sessions!

use strict;
use warnings;

# Let's cook again:
# Did you ever eat a mixed salat with hot roasted chichen breast?
# We'll make one:

print "Cut green salat in stripes\n";
print "Cut a tomato in pieces\n";
print "Cut half of a cucumber in pieces\n";
print "Cut a paprika in stripes\n";
print "Mix everything.\n";
print "Add some dressing\n";
print "Add some salt\n";
print "Add some pepper\n";
print "Cut a chicken breast in stripes\n";
print "Roast the chicken breast stripes\n";
print "Put them over the salat\n";

# Much typing, we need a more simple way, otherwise we won't finish the
# writing before dinner and I want the salat for lunch!

# We need to "cut" some things and "add" some things. Let's combine the
# "add" items first:

sub add {
	print "Add some $_[0]\n";
}

# A "sub" is a piece of source code which has a name and could be called by
# this name.
# subs are like Perl commands (think of print, for example) but they are
# written by the developer and need to be placed in the same file where they
# are used.
#
# The name of a sub follows the same conventions like names for
# variables: a-z, 0-9 and _
# A-Z are supported by Perl but rarely used by the developers.
#
# A sub uses the same { } brackets to enclose a block of source code you
# already know from "if" and "for".
# Our brand new sub shown above is called "add" and contains one line of
# source code. I could also name it "the_sub_which_adds_something_to_our_salat"
# but I'm, lazy and "add" is much easier to write.
# There's a special variable called $_[0]. Please take it as it is for the
# moment, we'll discuss it in a later lesson.

# To call a sub, just write its name followed by zero or more arguments which
# should be given to the sub.

add "dressing";
add "salt";
add "pepper";

# Whatever you use as an argument will live in the special variable $_[0].

# We'll do the same for the cut-items:

sub cut {
	print "cut $_[0] in $_[1]\n";
}

# Here we got two arguments, the foot and the cut style. Many arguments must be
# separated by commas.

cut "green salat",        "stripes";
cut "a tomato",           "pieces";
cut "half of a cucumber", "pieces";
cut "a paprika",          "stripes";
cut "a chicken breast",   "stripes";

# The second arguments goes to $_[1] and if we had a third one, it would go to
# $_[2] and so on.

# Now order everything to get the same salat
print "Ordered salat:\n";
cut "green salat",        "stripes";
cut "a tomato",           "pieces";
cut "half of a cucumber", "pieces";
cut "a paprika",          "stripes";
print "Mix everything\n";
add "dressing";
add "salt";
add "pepper";
cut "a chicken breast", "stripes";
print "Roast the chicken breast stripes\n";
print "Put them over the salat\n";

# You could use every comamnd within a sub the same way you use it in your main
# program. Usually, all subs are placed between the "use" - lines and the start
# of the main program. This isn't required but it makes things much easier in
# big programs.

# Now press F5 and Padre will execute this script.
#
# You'll see a new window on the bottom of Padre which shows you the
# output of this script.
# We have a lot of samples with a lot of output in this file, so first try to
# match each block of output to the correct source code sample and try to
# understand what happens. Play around with the source if you want and change
# things to get other results.

# If you understood this lesson, this is easy for you:
# We always use print "text\n"; and you know - I'm lazy.
# Please write a sub which outputs the text given as an argument followed by
# a newline \n. If you call it printn then the following should work:

# <Place your sub here>

#printn "First line";
#printn "Second line";

# Remove the comment chars # in front of the lines to make them work.

# Now we got a really useful function, so we should use it: Change the subs
# for cutting and adding items to your your new print-with-newline sub.
# You chould change them above or copy them here, but please notice that
# a typical Perl script may use every sub-name only once.
