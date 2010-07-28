package Padre::Document::Perl::FunctionList;

use 5.008;
use strict;
use warnings;
use Padre::Task::FunctionList ();

our $VERSION = '0.68';
our @ISA     = 'Padre::Task::FunctionList';





######################################################################
# Padre::Task::FunctionList Methods
my $n = "\\cM?\\cJ";
our $sub_search_re=qr/
		(?:
		(?:$n)*__(?:DATA|END)__\b.*
		|
		$n$n=\w+.*?$n$n=cut\b(?=.*?$n$n)
		|
		(?:^|$n)\s*sub\s+(\w+(?:::\w+)*)
		)
	/sx;

sub find {
	return grep { defined $_ } $_[1] =~ /$sub_search_re/g;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
