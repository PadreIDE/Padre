package Padre::Project::Null;

use 5.008;
use strict;
use warnings;
use Padre::Project ();

our $VERSION = '1.00';
our @ISA     = 'Padre::Project';

use overload 'bool' => sub () {0};

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
