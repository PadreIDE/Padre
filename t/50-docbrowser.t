use Test::More 'no_plan';
use File::Spec::Functions qw( catfile );
use URI;

BEGIN {


use_ok( 'Padre::DocBrowser' ) ;

}

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
#my $mw = Padre->ide->wx->main_window;
#Padre->ide->wx->MainLoop;
