package Padre::Document::Java::FunctionList;

use 5.008;
use strict;
use warnings;
use Padre::Task::FunctionList ();

our $VERSION = '0.91';
our @ISA     = 'Padre::Task::FunctionList';

######################################################################
# Padre::Task::FunctionList Methods

my $n                   = "\\cM?\\cJ";
my $method_search_regex = qr/
			\/\*\*.+?\*\/
			|
			\/\/.+?$n
			|
			(?:^|$n)\s*
			(?:
				(?:
				  (?:
					(?: public|protected|private|abstract|static|
					final|native|synchronized|transient|volatile|
					strictfp)
					\s+
				  ){0,2}            # zero to 2 method modifiers
				  (?: [\w\[\]<>]+)  # return data type
				  \s+
				  (\w+)             # method name
				  \s*
				  \(.*?\)           # parantheses around the parameters
				 )
			)
	/sx;

sub find {
	return grep { defined $_ } $_[1] =~ /$method_search_regex/g;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
