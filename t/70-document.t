#!/usr/bin/perl

use strict;
use warnings;
#use Test::NeedsDisplay;
use Test::More;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

use Test::NoWarnings;
use File::Spec  ();
use t::lib::Padre;
use t::lib::Padre::Editor;

my $tests;
plan tests => $tests+1;

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
my $doc_3    = Padre::Document->new(
		filename => $file_3,
	);
#editor   => $editor_3,

SCOPE: {
	isa_ok($doc_3, 'Padre::Document');
	isa_ok($doc_3, 'Padre::Document::Perl');
	is($doc_3->filename, $file_3, 'filename');
	BEGIN { $tests += 3; }
}

# test guess_mimetype
my %mimes;
BEGIN {
	%mimes = ( 
		'eg/hello_world.pl'                => 'application/x-perl',
		'eg/perl5.pod'                     => 'application/x-perl',
		'eg/perl5_with_perl6_example.pod'  => 'application/x-perl',
		'eg/perl6.pod'                     => 'application/x-perl6',
		'eg/Perl6Class.pm'                 => 'application/x-perl6',
	);
}

foreach my $file ( keys %mimes ) {
	my $editor = t::lib::Padre::Editor->new;
	my $doc    = Padre::Document->new(
		filename => $file,
	);

	is($doc->guess_mimetype, $mimes{$file}, "mime of $file");
	BEGIN { $tests += scalar keys %mimes; }
}

