package Padre::Document::Java::FunctionList;

use 5.008;
use strict;
use warnings;
use Padre::Task::FunctionList ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task::FunctionList';

######################################################################
# Padre::Task::FunctionList Methods

my $newline =
	qr{\cM?\cJ}; # recognize newline even if encoding is not the platform default (will not work for MacOS classic)
my $method_search_regex = qr{
			/\*.+?\*/          # block comment
			|
			\/\/.+?$newline    # line comment
			|
			(?:^|$newline)     # text start or newline 
			\s* 
			(?:
			  (?:
				(?: public|protected|private|abstract|static|
				final|native|synchronized|transient|volatile|
				strictfp)
				\s+
			  ){0,2}            # zero to 2 method modifiers
			  (?: <\w+>\s+ )?   # optional: generic type parameter
			  (?: [\w\[\]<>]+)  # return data type
			  \s+
			  (\w+)             # method name
			  \s*
			  \(.*?\)           # parentheses around the parameters
			)
	}sx;

sub find {
	return grep { defined $_ } $_[1] =~ /$method_search_regex/g;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
