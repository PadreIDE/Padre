#!/usr/bin/perl

use strict;
use Test::More;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

plan( 'no_plan' );

use Test::NoWarnings;
use File::Spec::Functions qw( catfile );
use File::Temp ();
use URI;

BEGIN {
	$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
}

use_ok( 'Padre::DocBrowser' ) ;
use_ok( 'Padre::Task::DocBrowser' );

my $db = Padre::DocBrowser->new();

ok( $db, 'instance Padre::DocBrowser' );

my $doc = Padre::Document->new( 
  filename => catfile( 'lib' , 'Padre' , 'DocBrowser.pm'  )  );
isa_ok( $doc, 'Padre::Document' );

my $docs = $db->docs( $doc );
isa_ok( $docs , 'Padre::Document' );

my $tm = $db->resolve( URI->new( 'perldoc:Test::More' ) );
isa_ok( $tm , 'Padre::Document' );
ok( $tm->get_mimetype eq 'application/x-pod' , 'Resolve from uri' );


my $view = $db->browse( $tm ) ;
isa_ok( $view , 'Padre::Document' );
ok( $view->get_mimetype eq 'text/xhtml' , 'Got html view' );

