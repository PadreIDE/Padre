package Padre::Config::Patch;

# Support library for writing config file migration scripts

use strict;
use warnings;

our $VERSION = '0.26';

use YAML::Tiny ();
use Exporter   ();

# Load the Padre::Config module so we can get the
# config file location.
use Padre::Config ();

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
