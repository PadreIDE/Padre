package Padre::Plugin::Devel::Crash;

# (To the tune of Flash by Queen)
#
# DUN dun dun dun dun dun dun dun
# dun dun dun dun dun dun dun dun
# CRASH! Aaaaaaah!
# Explosive debugging task!
# DUN dun dun dun dun dun dun dun
# dun dun dun dun dun dun dun dun
# CRASH! Aaaaaaah!
# Simulates a failing task!
# DUN dun dun dun dun dun dun dun
# ...
# ...

# TO DO: Replace this with some use of Padre::Task::Eval so we don't need
# an entire dedicated class just for this.

use 5.008;
use strict;
use warnings;
use Padre::Task ();

our $VERSION = '0.65';
our @ISA     = 'Padre::Task';

sub run {
	sleep 5;
	die "This is a debugging task that simply crashes after running for 5 seconds!";
}

sub finish {
	warn "This should never be reached";
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
