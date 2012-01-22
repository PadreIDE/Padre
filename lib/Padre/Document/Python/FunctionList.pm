package Padre::Document::Python::FunctionList;

use 5.008;
use strict;
use warnings;
use Padre::Task::FunctionList ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task::FunctionList';

######################################################################
# Padre::Task::FunctionList Methods

my $n = "\\cM?\\cJ";
our $function_search_re = qr/
		(?:
			\"\"\".*?\"\"\"
			|
			(?:^|$n)\s*
			(?:
				(?:def)\s+(\w+)
				|
				(?:(\w+)\s*\=\s*lambda)
			)
		)
	/sx;

sub find {
	return grep { defined $_ } $_[1] =~ /$function_search_re/g;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
