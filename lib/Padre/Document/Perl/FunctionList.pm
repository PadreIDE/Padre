package Padre::Document::Perl::FunctionList;

use 5.008;
use strict;
use warnings;
use Padre::Task::FunctionList ();
use Parse::Functions::Perl ();

our $VERSION = '1.01';
our @ISA     = ('Padre::Task::FunctionList', 'Parse::Functions::Perl');

1;

# Copyright 2008-2014 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
