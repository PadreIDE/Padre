package Padre::Document::Java;

use 5.008;
use strict;
use warnings;
use Padre::Document::DoubleSlashComment ();

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Document::DoubleSlashComment
};

# Java Keywords
# The list is obtained from src/scite/src/cpp.properties
sub scintilla_key_words {
	return [
		[   qw(abstract assert boolean break byte case catch char class
const continue default do double else enum extends final finally float for
goto if implements import instanceof int interface long
native new package private protected public
return short static strictfp super switch synchronized this throw throws
transient try var void volatile while)
		],
	];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
