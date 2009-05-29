package Padre::DocBrowser::POD;

use 5.008;
use strict;
use warnings;
use Config     ();
use IO::Scalar ();
use File::Spec ();
use File::Spec::Functions;
use Pod::Simple::XHTML ();
use Pod::Abstract; ();
use Padre::DocBrowser::document ();
use File::Temp                  ();

our $VERSION = '0.36';

use Class::XSAccessor constructor => 'new', getters => {
	get_provider => 'provider',
};

sub provider_for {
	'application/x-perl', 'application/x-pod',;
}

# uri schema like http:// pod:// blah://
sub accept_schemes {
	'pod', 'perldoc',;
}

sub viewer_for {
	'application/x-pod',;
}

sub resolve {
	my $self  = shift;
	my $ref   = shift;
	my $hints = shift;
	my ( $fh, $tempfile ) = File::Temp::tempfile();

	my @args = (
		'-u', '-r',
		"-d$tempfile",
		( exists $hints->{lang} )
		? ( '-L', ( $hints->{lang} ) )
		: (),
		$ref
	);
	my $pd = Padre::DocBrowser::pseudoPerldoc->new( args => \@args );
	$pd->process();
	my $pa = Pod::Abstract->load_file($tempfile);
	close $fh;
	unlink($tempfile);

	my $doc = Padre::DocBrowser::document->new( body => $pa->pod );
	$doc->mimetype('application/x-pod');
	my $title_from = $hints->{title_from_section} || 'NAME';
	my ($name) = $pa->select("/head1[\@heading =~ {$title_from}]");
	if ($name) {
		my $text = $name->text;
		my ($module) = $text =~ /([^\s]+)/g;
		$doc->title($module);
	}
	unless ( $pa->select('/pod') || $pa->select('/head1') ) {
		warn "$ref has no pod";

		# Unresolvable ?
		return;
	}
	return $doc;

	# Perldoc failed - Unresolvable
	return;
}

sub generate {
	my $self = shift;
	my $doc  = shift;
	$doc->mimetype('application/x-pod');
	return $doc;
	#### TODO , pod extract / pod tidy ?
}

sub render {
	my $self = shift;
	my $doc  = shift;
	my $data = '';
	my $pod  = IO::Scalar->new( \$doc->body );
	my $out  = IO::Scalar->new( \$data );
	my $v    = Pod::Simple::XHTML->new;
	$v->perldoc_url_prefix('perldoc:');
	$v->output_fh($out);
	$v->parse_file($pod);
	my $response = Padre::DocBrowser::document->new;
	$response->body( ${ $out->sref } );
	$response->mimetype('text/xhtml');
	return $response;
}

1;

package Padre::DocBrowser::pseudoPerldoc;
use strict;
use warnings;
use base qw( Pod::Perldoc );
use Pod::Perldoc::ToPod;

sub VERSION {1}

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	return $self;
}

## Lie to Pod::PerlDoc - and avoid it's autoloading implementation
sub find_good_formatter_class {
	$_[0]->{'formatter_class'} = 'Pod::Perldoc::ToPod';
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
