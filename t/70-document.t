#!/usr/bin/perl

package PadreTest::Config;

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
}

sub editor_file_size_limit {
	return 500000;
}

package main;

use strict;
use warnings;
use Test::More;
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

# Test files
my %MIMES = (
	'eg/perl5/hello_world.pl'                => 'application/x-perl',
	'eg/perl5/perl5.pod'                     => 'application/x-perl',
	'eg/perl5_with_perl6_example.pod'  	 => 'application/x-perl',
	'eg/perl6/perl6.pod'                     => 'application/x-perl6',
	'eg/perl6/Perl6Class.pm'                 => 'application/x-perl6',
);

plan tests => 11;

use Test::NoWarnings;
use File::Spec ();
use t::lib::Padre;
use t::lib::Padre::Editor;
use Padre::Document;
use Padre::Document::Perl;
use Padre::MimeTypes;

my $config = PadreTest::Config->new();

# Fake that Perl 6 support is enabled
Padre::MimeTypes->add_mime_class('application/x-perl6', 'Padre::Document::Perl');

my $editor_1 = t::lib::Padre::Editor->new;
my $doc_1    = Padre::Document->new(config => $config);

SCOPE: {
	isa_ok($doc_1, 'Padre::Document');
	ok(not(defined $doc_1->filename), 'no filename');
}

my $editor_3 = t::lib::Padre::Editor->new;
my $file_3   = File::Spec->catfile('eg', 'hello_world.pl');
my $doc_3    = Padre::Document->new(
	filename => $file_3,
	config => $config,
);

isa_ok($doc_3, 'Padre::Document');
isa_ok($doc_3, 'Padre::Document::Perl');
is($doc_3->filename, $file_3, 'filename');

foreach my $file ( keys %MIMES ) {
	my $editor = t::lib::Padre::Editor->new;
	my $doc    = Padre::Document->new(
		filename => $file,
		config => $config,
	);
	is($doc->guess_mimetype, $MIMES{$file}, "mime of $file");
}

END {
    unlink for
      'eg/hello_world.pl',
      'eg/perl5/perl5_with_perl6_example.pod',
      ;
}
