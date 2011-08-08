package Padre::Wx::Frame::Null;

# This is an empty null frame primarily designed to serve as a
# Wx::PlThreadEvent conduit in the thread slave master mechanism.

use 5.008;
use strict;
use warnings;
use Wx                       ();
use Padre::Wx::Role::Conduit ();

our $VERSION = '0.89';
our @ISA     = qw{
	Padre::Wx::Role::Conduit
	Wx::Frame
};

1;
