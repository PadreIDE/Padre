package Padre::Document::Perl::FunctionList;

use 5.008;
use strict;
use warnings;
use Padre::Task::FunctionList ();

our $VERSION = '0.90';
our @ISA     = 'Padre::Task::FunctionList';

# TODO: the regex containing func|method should either reuse what
# we have in PPIx::EditorTools::Outline or copy the list from there
# for now let's leave it as it is and focus on improving the Outline
# code and then we'll see if we reuse or copy paste.

######################################################################
# Padre::Task::FunctionList Methods

my $n = "\\cM?\\cJ";
our $sub_search_re = qr/
		(?:
			${n}__(?:DATA|END)__\b.*
			|
			$n$n=\w+.*?$n\s*?$n=cut\b(?=.*?(?:$n){1,2})
			|
			(?:^|$n)\s*
			(?:
				(?:sub|func|method)\s+(\w+(?:::\w+)*)
				|
				\* (\w+(?:::\w+)*) \s*=\s* (?: sub\b | \\\& )
			)
		)
	/sx;

sub find {
	return grep { defined $_ } $_[1] =~ /$sub_search_re/g;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
