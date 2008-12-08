#!/usr/bin/perl

use strict;
use warnings;
use Test::NeedsDisplay;
use Test::More;
use File::Spec  ();
use t::lib::Padre;
use t::lib::Padre::Editor;

my $tests;
plan tests => $tests;

use Padre::Document;

my $editor_1 = t::lib::Padre::Editor->new;
my $doc_1 = Padre::Document->new;
#(editor => $editor_1);

SCOPE: {
	isa_ok($doc_1, 'Padre::Document');
	ok(not(defined $doc_1->filename), 'no filename');
    BEGIN { $tests += 2; }
}

#my $editor_2 = t::lib::Padre::Editor->new;
#my $file_2   = File::Spec->catfile('eg', 'no_such_file.txt');
#my $doc_2 = Padre::Document->new(
#		editor   => $editor_2,
#		filename => $file_2,
#	);
#SCOPE: {
#	isa_ok($doc_2, 'Padre::Document');
#    BEGIN { $tests += 1; }
#}
#


my $editor_3 = t::lib::Padre::Editor->new;
my $file_3   = File::Spec->catfile('eg', 'hello_world.pl');
my $doc_3 = Padre::Document->new(
		filename => $file_3,
	);
#editor   => $editor_3,

SCOPE: {
	isa_ok($doc_3, 'Padre::Document');
	isa_ok($doc_3, 'Padre::Document::Perl');
	is($doc_3->filename, $file_3, 'filename');
    BEGIN { $tests += 3; }
}


