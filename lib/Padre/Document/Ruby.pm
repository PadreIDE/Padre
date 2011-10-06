package Padre::Document::Ruby;

use 5.008;
use strict;
use warnings;
use Padre::Document::HashComment ();

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Document::HashComment
};

# Ruby Keywords
# The list is obtained from src/scite/src/ruby.properties
sub scintilla_key_words {
	return [
		[   qw(__FILE__ and def end in or self unless __LINE__ begin
defined? ensure module redo super until BEGIN break do false next rescue
then when END case else for nil retry true while alias class elsif if
not return undef yield)
		],
	];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
