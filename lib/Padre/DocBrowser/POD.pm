package Padre::DocBrowser::POD;

use strict;
use warnings;

our $VERSION = '0.24';

use Padre::Pod::Viewer;
use Pod::Simple::XHTML;
use Data::Dumper;
use Padre::Document;
use IO::Scalar;
use Scalar::Util qw( blessed ); 

use Class::XSAccessor
  constructor => 'new', 
  getters => {
    get_provider => 'provider',
  };


sub provider_for {
  'application/x-perl' ,
  'application/x-pod',
}

# uri schema like http:// pod:// blah://
sub accept_schemes {
	'pod', 
	'perldoc',
}

sub viewer_for {
	'application/x-pod',
}


sub resolve {
    my ($self,$ref) = @_;
       
    my $path = Padre::Pod::Viewer->module_to_path( $ref );
    if ( $path ) {
		my $doc = Padre::Document->new( filename => $path );
		$doc->set_mimetype( 'application/x-pod' );
		return $doc;
    }
    return;
}

sub generate {
    my ($self,$doc) = @_;
    my $r = Padre::Document->new;
    $r->{original_content} = $doc->{original_content};;
    $r->set_mimetype( 'application/x-pod' );
    return $r;
#### TODO , pod extract / pod tidy ?

    my $response = Padre::Document->new();
    $response->set_mimetype( 'application/x-pod' );
	my $parser = Pod::Simple->new;
	my $pod = '';
	$parser->output_fh( IO::Scalar->new( \$pod ) );
	$parser->parse_string_document( $doc->{original_content} ) ;
	$response->{original_content} = $pod;
	
	return $response;
	
}
    
sub render {
	my($self,$doc) = @_;    
	my $data = '';
	#warn "ORIGINAL DOCS: " . $doc->{original_content} ;
	my $podfile = IO::Scalar->new( 
		\$doc->{original_content}
	); # want text_get ??

    	my $out = new IO::Scalar \$data;
	my $v = Pod::Simple::XHTML->new( );
	$v->perldoc_url_prefix( 'perldoc:' );	
	$v->output_fh( $out );
	$v->parse_file( $podfile );
	#warn "RENDER OUTPUT :: " . ${ $out->sref };
	my $response = Padre::Document->new();
	$response->{original_content} = ${ $out->sref };
	$response->set_mimetype( 'text/xhtml' );
	return $response;
   ;
}


1;
