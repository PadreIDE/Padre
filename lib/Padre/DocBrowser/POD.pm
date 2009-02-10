package Padre::DocBrowser::POD;

use 5.008;
use strict;
use warnings;
use Config             ();
use IO::Scalar         ();
use File::Spec         ();
use Pod::Simple::XHTML ();
use Padre::Document    ();

our $VERSION = '0.27';

use Class::XSAccessor
	constructor => 'new', 
	getters     => {
		get_provider => 'provider',
	};

sub provider_for {
	'application/x-perl',
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
	my $self = shift;
	my $ref  = shift;
	my $path = $self->_module_to_path( $ref );
	if ( $path ) {
		my $doc = Padre::Document->new( filename => $path );
		$doc->set_mimetype('application/x-pod');
		return $doc;
	}
	return;
}

sub generate {
	my $self = shift;
	my $doc  = shift;
	my $r    = Padre::Document->new;
	$r->{original_content} = $doc->{original_content};;
	$r->set_mimetype('application/x-pod');
	return $r;

	#### TODO , pod extract / pod tidy ?
	my $response = Padre::Document->new;
	$response->set_mimetype('application/x-pod');
	my $parser = Pod::Simple->new;
	my $pod = '';
	$parser->output_fh( IO::Scalar->new(\$pod) );
	$parser->parse_string_document( $doc->{original_content} ) ;
	$response->{original_content} = $pod;
	return $response;
	
}

sub render {
	my $self = shift;
	my $doc  = shift;
	my $data = '';
	my $pod  = IO::Scalar->new( 
		\$doc->{original_content}
	); # want text_get ??

	my $out = IO::Scalar->new( \$data );
	my $v   = Pod::Simple::XHTML->new;
	$v->perldoc_url_prefix( 'perldoc:' );
	$v->output_fh( $out );
	$v->parse_file( $pod );

	my $response = Padre::Document->new;
	$response->{original_content} = ${$out->sref};
	$response->set_mimetype('text/xhtml');
	return $response;
}

sub _module_to_path {
	my $self   = shift;
	my $module = shift;
	my $root   = $module;
	my $file   = $module;
	$file =~ s{::}{/}g;
	my $path;

	my $poddir = File::Spec->catdir( $Config::Config{privlib}, 'pod' );
	foreach my $dir ( $poddir, @INC ) {
		my $fpath = File::Spec->catfile($dir, $file);
		if ( -e "$fpath.pm" ) {
			$path = "$fpath.pm";
		} elsif ( -e "$fpath.pod" ) {
			$path = "$fpath.pod";
		}
	}

	return $path;
}

1;
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
