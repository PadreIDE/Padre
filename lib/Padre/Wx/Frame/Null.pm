package Padre::Wx::Frame::Null;

# This is an empty null frame primarily designed to serve as a
# Wx::PlThreadEvent conduit in the thread slave master mechanism.

use 5.008;
use strict;
use warnings;
use Wx                       ();
use Padre::Wx::Role::Conduit ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Conduit
	Wx::Frame
};

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
