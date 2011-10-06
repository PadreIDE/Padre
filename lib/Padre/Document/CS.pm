package Padre::Document::CS;

use 5.008;
use strict;
use warnings;
use Padre::Document::DoubleSlashComment ();

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Document::DoubleSlashComment
};

# C# Keywords
# The list is obtained from src/scite/src/cpp.properties
sub scintilla_key_words {
	return [
		[   qw(abstract as ascending base bool break by byte case catch char checked
class const continue decimal default delegate descending do double else enum
equals event explicit extern false finally fixed float for foreach from goto group if
implicit in int interface internal into is join lock let long namespace new null
object on operator orderby out override params private protected public
readonly ref return sbyte sealed select short sizeof stackalloc static
string struct switch this throw true try typeof uint ulong
unchecked unsafe ushort using var virtual void where while)
		],
	];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
