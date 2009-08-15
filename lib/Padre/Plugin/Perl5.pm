package Padre::Plugin::Perl5;

use 5.008;
use strict;
use warnings;
use Padre::Plugin ();

our $VERSION = '0.43';
our @ISA     = 'Padre::Plugin';

sub padre_interfaces {
	'Padre::Plugin' => 0.43, 'Padre::Wx::Main' => 0.43,;
}

sub plugin_name {
	'Perl 5';
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
