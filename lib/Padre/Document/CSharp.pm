package Padre::Document::CSharp;

use 5.008;
use strict;
use warnings;
use Padre::Constant   ();
use Padre::Role::Task ();
use Padre::Document   ();

our $VERSION = '0.91';
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

# C# keyword list is obtained from src/scite/src/cpp.properties
# added missing keyword volatile
sub scintilla_key_words {
	return [
		[   qw{
				abstract as ascending base bool break by byte case catch char
				checked class const continue decimal default delegate
				descending do double else enum equals event explicit extern
				false finally fixed float for foreach from goto group if
				implicit in int interface internal into is join lock let long
				namespace new null object on operator orderby out override
				params private protected public readonly ref return sbyte
				sealed select short sizeof stackalloc static string struct
				switch this throw true try typeof uint ulong unchecked unsafe
				ushort using var virtual void volatile where while
				}
		]
	];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
