#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Padre::Constant;

BEGIN {

	require Win32 if Padre::Constant::WIN32;
	unless ( $ENV{DISPLAY} or Padre::Constant::WIN32 ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	if ( Padre::Constant::WIN32 ? Win32::IsAdminUser() : !$< ) {
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

use_ok('Padre::Browser');
use_ok('Padre::Task::Browser');
use_ok('Padre::Browser::Document');

my $db = Padre::Browser->new();

ok( $db, 'instance Padre::Browser' );

my $doc = Padre::Browser::Document->load( catfile( 'lib', 'Padre', 'Browser.pm' ) );
isa_ok( $doc, 'Padre::Browser::Document' );
ok( $doc->mimetype eq 'application/x-perl', 'Mimetype is sane' );
my $docs = $db->docs($doc);
isa_ok( $docs, 'Padre::Browser::Document' );

my $tm = $db->resolve( URI->new('perldoc:Test::More') );
isa_ok( $tm, 'Padre::Browser::Document' );
ok( $tm->mimetype eq 'application/x-pod', 'Resolve from uri' );
cmp_ok( $tm->title, 'eq', 'Test::More', 'Doc title discovered' );

my $view = $db->browse($tm);
isa_ok( $view, 'Padre::Browser::Document' );
ok( $view->mimetype eq 'text/xhtml', 'Got html view' );
cmp_ok( $view->title, 'eq', 'Test::More', 'Title' );


