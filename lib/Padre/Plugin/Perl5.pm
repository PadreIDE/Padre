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
