#!/usr/bin/perl

# This file assumes that you already read (and understood) 01_hello_world.pl!

use strict; # This will be discussed later

# Perl accepts many things and runs even very bad written code. The following
# line tells Perl to be more pedantic and show warnings (not errors) if there
# is code which is supposed not to do what you want. If you're just testing
# around and everything works, you could disable the follow line by making it
# a comment (add a # before the line), but you should always use it for
# productional scripts.
use warnings;

# This line does nothing more than getting the current time and even if
# it now looks very, very complex to you, don't worry, it's not too
# complicated to understand:
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( time() );

# "my" at the beginning tells Perl that the following variables are dedicated
# to this file. You don't care about this, currently, but remember that at the
# time of this writing, this editor contains of 158 files - all for one program.
# A variable is a piece of memory which holds some information for you, just
# like a postit note. Unlike other languages, Perl cares about size and type of
# information itself, so you don't need to do it yourself. Every variable
# has a name which has only few naming conventions:
#  - The first char MUST be a dollar sign $
#  - It may contain letters, numbers and the underscore _
#  - There must be at least one char after the $ sign.
# That's it! You could use $egg or $cake_made_of_eggs_and_milk_and_other_things
# it's really up to you what you use.
# It's a good idea to name variables by their usage because you need to
# know why you used it and for which purpose even in a 3000 lines file.
#
# Most Perl developers advoid using upper case chars (A-Z) for variable
# names. It's a good idea to follow this way even if there is no technical
# requirement to do so.
#
# This line has many variables all shown in a comma (,) separated list. Their
# names tell you what they contain:
#  - $sec for the seconds
#  - $min for the minutes
# and so on. Even if you don't understand every name, it's enough for now.
#
# = assigns some value to something. The value is always on the right side
# and the variable(s) are always on the left side.
#
# localtime(time) gives you the current time. You'll understand the exact
# usage later on, please treat it as a fixed text for now.

# Let's print the time to the user. Variables could be used within printed
# text like normal words:
print "The time is $hour:$min\n";

# Now press F5 and Padre will execute this script.
#
# You'll see a new window on the bottom of Padre which shows you the
# output of this script. Congratulations, now you know the time.

# Please go ahead and write your own print command below showing the current
# time including seconds. You could also inspect the other variables, if you
# want. Notice that the month and year values won't show what you expect, but
# this is another story...
