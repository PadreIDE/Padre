#!/usr/bin/perl

use strict;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	unless ($<) {
		plan skip_all => 'Cannot run as root';
		exit 0;
	}
}

plan tests => 14;

use Test::NoWarnings;
use File::Spec::Functions qw( catfile );
use File::Temp ();
use URI;

BEGIN {
	$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
}

use_ok('Padre::DocBrowser');
use_ok('Padre::Task::DocBrowser');
use_ok('Padre::DocBrowser::document');

my $db = Padre::DocBrowser->new();

ok( $db, 'instance Padre::DocBrowser' );

my $doc = Padre::DocBrowser::document->load( catfile( 'lib', 'Padre', 'DocBrowser.pm' ) );
isa_ok( $doc, 'Padre::DocBrowser::document' );
ok( $doc->mimetype eq 'application/x-perl', 'Mimetype is sane' );
my $docs = $db->docs($doc);
isa_ok( $docs, 'Padre::DocBrowser::document' );

my $tm = $db->resolve( URI->new('perldoc:Test::More') );
isa_ok( $tm, 'Padre::DocBrowser::document' );
ok( $tm->mimetype eq 'application/x-pod', 'Resolve from uri' );
cmp_ok( $tm->title, 'eq', 'Test::More', 'Doc title discovered' );

my $view = $db->browse($tm);
isa_ok( $view, 'Padre::DocBrowser::document' );
ok( $view->mimetype eq 'text/xhtml', 'Got html view' );
cmp_ok( $view->title, 'eq', 'Test::More', 'Title' );


