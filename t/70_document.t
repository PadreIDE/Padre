#!/usr/bin/perl

package PadreTest::Config;

use strict;
use warnings;

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
}

sub editor_file_size_limit {
	return 500000;
}

sub lang_perl6_auto_detection {
	return 0;
}

package main;

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

# Test files
my %MIMES = (
	'eg/perl5/hello_world.pl'         => 'application/x-perl',
	'eg/perl5/perl5.pod'              => 'text/x-pod',
	'eg/perl5_with_perl6_example.pod' => 'text/x-pod',
	'eg/perl6/perl6.pod'              => 'text/x-pod',
	'eg/xml/xml_example'              => 'text/xml',
	'eg/tcl/hello_tcl'                => 'application/x-tcl',
	'eg/tcl/portable_tcl'             => 'application/x-tcl',
	'eg/ruby/hello_world.rb'          => 'application/x-ruby',
	'eg/ruby/hello_world_rb'          => 'application/x-ruby',
	'eg/python/hello_py'              => 'text/x-python',
);

plan tests => 9 + scalar keys %MIMES;

# This should only be used to skip dependencies out of the Document.pm - scope
# which are not required for testing, like Padre->ide. Never skip larger blocks
# with this!
$ENV{PADRE_IS_TEST} = 1;

use Test::NoWarnings;
use Encode     ();
use File::Spec ();
use t::lib::Padre;
use t::lib::Padre::Editor;
use Padre::Document;
use Padre::Document::Perl;
use Padre::MIME;
use Padre::Locale ();

my $config = PadreTest::Config->new;

# Fake that Perl 6 support is enabled
Padre::MIME->find('application/x-perl6')->plugin('Padre::Document::Perl');

my $editor_1 = t::lib::Padre::Editor->new;
my $doc_1 = Padre::Document->new( config => $config );

SCOPE: {
	isa_ok( $doc_1, 'Padre::Document' );
	ok( not( defined $doc_1->filename ), 'no filename' );
}

my $editor_3 = t::lib::Padre::Editor->new;
my $file_3   = File::Spec->rel2abs( File::Spec->catfile( 'eg', 'hello_world.pl' ) );
my $doc_3    = Padre::Document->new(
	filename => $file_3,
	config   => $config,
);

isa_ok( $doc_3, 'Padre::Document' );
isa_ok( $doc_3, 'Padre::Document::Perl' );
is( $doc_3->filename, $file_3, 'filename' );

foreach my $file ( sort keys %MIMES ) {
	my $editor = t::lib::Padre::Editor->new;
	my $doc    = Padre::Document->new(
		filename => $file,
		config   => $config,
	);
	is( $doc->guess_mimetype, $MIMES{$file}, "mime of $file" );
}

# The following tests are for verifying that
# "ticket #889: Padre saves non-ASCII characters as \x{XXXX}"
# does not happen again
my ( $encoding, $content );

# English (ASCII)
$encoding = Padre::Locale::encoding_from_string(q{say "Hello!";});
is( $encoding, 'ascii', "Encoding should be ascii for English" );

# Russian (UTF-8)
$content = q{say "Превед!";};
Encode::_utf8_on($content);
$encoding = Padre::Locale::encoding_from_string($content);
is( $encoding, 'utf8', "Encoding should be utf8 for Russian" );

# Arabic (UTF-8)
$content = q{say "مرحبا!"; };
Encode::_utf8_on($content);
$encoding = Padre::Locale::encoding_from_string($content);
is( $encoding, 'utf8', "Encoding should be utf8 for Arabic" );

END {
	unlink for
		'eg/hello_world.pl',
		'eg/perl5/perl5_with_perl6_example.pod',
		;
}
