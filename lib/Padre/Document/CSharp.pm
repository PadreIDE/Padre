package Padre::Document::CSharp;

use 5.008;
use strict;
use warnings;
use Padre::Constant   ();
use Padre::Role::Task ();
use Padre::Document   ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Document
};


#####################################################################
# Padre::Document Task Integration

sub task_functions {
	return 'Padre::Document::CSharp::FunctionList';
}

sub task_outline {
	return undef;
}

sub task_syntax {
	return undef;
}

sub get_function_regex {
	my $name = quotemeta $_[1];
	return qr/
	        (?:^|[^# \t-])
	        [ \t]*
		((?: (public|protected|private|
		      abstract|static|sealed|virtual|override|
		      explicit|implicit|operator|extern)\s+)
		     {0,4}             # zero to 4 method modifiers
		     (?: [\w\[\]<>,]+) # return data type
		     \s+
		     $name
   		     (?: <\w+>)?        # optional: generic type parameter
	        )
		/x;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
