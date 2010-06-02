package Padre::Document::Config;

use 5.008;
use strict;
use warnings;
use Padre::Document ();

our $VERSION = '0.63';
our @ISA     = 'Padre::Document';

sub comment_lines_str {
	return '#';
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
