package Padre::Document::CPP;

use 5.008;
use strict;
use warnings;
use Padre::Document::DoubleSlashComment ();

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Document::DoubleSlashComment
};

# C/C++ Keywords
# The list is obtained from src/scite/src/cpp.properties
sub scintilla_key_words {
	return [
		[   qw(and and_eq asm auto bitand bitor bool break
case catch char class compl const const_cast continue
default delete do double dynamic_cast else enum explicit export extern false float for
friend goto if inline int long mutable namespace new not not_eq
operator or or_eq private protected public
register reinterpret_cast return short signed sizeof static static_cast struct switch
template this throw true try typedef typeid typename union unsigned using
virtual void volatile wchar_t while xor xor_eq)
		],
	];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
