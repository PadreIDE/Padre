#!/usr/bin/perl

# This file assumes that you already read (and understood) earlier sessions!

use strict; # This will be discussed later
use warnings;

my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( time() );

# Let's say you want to go out and take a walk. What do you do?
# First, you look out of the window to check for sun or rain, then you
# decide on clothing which should fit the situation and finally you
# go out.
# Programs always need to decide things and it's as easy like
# if-there-is-rain-then-get-the-umbrella.

if ( $hour < 10 ) { print "Good morning!\n"; }

# This is a condition. It checks if $hour (which holds the hour of the
# current time as we knew from the last session) is lower-than the
# number 10.
# All conditions always have "yes" or "no" as a result, even for masters
# of Perl. On 8:30 o' clock, the result is yes, after lunch it's no.
# The leading "if" identifies the following as a condition. This must be
# written in surrounding brackets ( ).
# The program should do something if the result is yes and this something
# must be written in brackets, but this time { }.

# As this sample should run at any daytime, we need to add if-lines for
# the rest of the day:

elsif ( $hour == 12 ) { print "Out for lunch...\n"; }
elsif ( $hour <= 18 ) { print "Hello world!\n"; }
elsif ( $hour < 23 )  { print "Good night.\n"; }

# You noticed the els in front of the if? This means "try this condition
# only if the result of the last was no". Otherwise the condition <= 18
# (less-or-equal 18) would also match for 9 o' clock, but we want only
# the very first if to match this.

# Leaving out the if (and adding an e) allows us to set a last-resort
# without a condition:

else { print "sleep well!\n"; }

# If nothing else (<-- notice, it's the same in language) matches, this
# { something } is executed.
#
# Nobody forces you to use all three (if, elsif and else) parts, you could
# leave out the else or elsif part as you like. Also notice that there are
# no other commands (like print) allowed between the parts.

# Now press F5 and Padre will execute this script.
#
# You'll see a new window on the bottom of Padre which shows you the
# output of this script.

# You could also fill variables by just assigning a new value to them.
# If you want to test some times, just write the variable ($hour), the
# equal-sign = and the new number followed by the mandatory semicolon ;
# if a line before the if-block starts. Press F5 to see the result for each
# value.

# What about writing your own if-elsif-else - block, for example showing
# different messages for different seconds?
