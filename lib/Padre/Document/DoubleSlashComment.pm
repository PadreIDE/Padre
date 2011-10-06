package Padre::Document::DoubleSlashComment;

use 5.008;
use strict;
use warnings;
use Padre::Document ();

our $VERSION = '0.91';
our @ISA     = 'Padre::Document';

sub get_comment_line_string {
	return '//';
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
