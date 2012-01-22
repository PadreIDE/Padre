package Padre::Document::CSharp::FunctionList;

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
			/\*.+?\*/        # block comment
			|
			\/\/.+?$newline  # line comment
			|
			(?:^|$newline)   # text start or newline 
			\s*              
			(?:
			  (?: \[ [\s\w()]+ \]\s* )?  # optional annotations
			  (?:
				(?: public|protected|private|
				    abstract|static|sealed|virtual|override|
				    explicit|implicit|
				    operator|
				    extern)
				\s+
			  ){0,4}                     # zero to 2 method modifiers
			  (?: [\w\[\]<>,]+)          # return data type
			  \s+
			  (\w+)                      # method name
			  (?: <\w+>)?                # optional: generic type parameter
			  \s*
			  \(.*?\)                    # parentheses around the parameters
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
