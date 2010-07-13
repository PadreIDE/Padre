package Padre::Plugin::C;

use strict;
use warnings FATAL => 'all';
use base 'Padre::Plugin';

our $VERSION = '0.01';

sub padre_interfaces {
	'Padre::Plugin' => 0.66,
}

1;
