package Padre::Config::Patch;

# Support library for writing config file migration scripts

use strict;
use warnings;
use YAML::Tiny    ();
use Exporter      ();
use Padre::Config ();

our $VERSION = '0.26';

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
