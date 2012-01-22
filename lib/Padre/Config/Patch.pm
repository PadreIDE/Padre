package Padre::Config::Patch;

# Support library for writing config file migration scripts

use 5.008;
use strict;
use warnings;
use YAML::Tiny    ();
use Exporter      ();
use Padre::Config ();

our $VERSION = '0.94';

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
