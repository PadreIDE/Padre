package Padre::Browser::POD;

use 5.008;
use strict;
use warnings;
use Config                        ();
use File::Temp                    ();
use IO::Scalar                    ();
use Params::Util                  ();
use Pod::Simple::XHTML            ();
use Pod::Abstract                 ();
use Padre::Browser::Document      ();
use Padre::Browser::PseudoPerldoc ();

our $VERSION = '0.94';

use Class::XSAccessor {
	constructor => 'new',
	getters     => {
		get_provider => 'provider',
	},
};

sub provider_for {
	( 'application/x-perl', 'application/x-pod' );
}

# uri schema like http:// pod:// blah://
sub accept_schemes {
	'perldoc';
}

sub viewer_for {
	'application/x-pod';
}

sub resolve {
	my $self  = shift;
	my $ref   = shift;
	my $hints = shift;
	my $query = $ref;

	if ( Params::Util::_INSTANCE( $ref, 'URI' ) ) {
		$query = $ref->opaque;
	}
	my ( $docname, $section ) = split_link($query);

	# Put Pod::Perldoc to work on $query
	my ( $fh, $tempfile ) = File::Temp::tempfile();

	my @args = (
		'-u',
		"-d$tempfile",
		( exists $hints->{lang} )
		? ( '-L', ( $hints->{lang} ) )
		: (),
		( exists $hints->{perlfunc} ) ? '-f'
		: (),
		( exists $hints->{perlvar} ) ? '-v'
		: (),
		$query
	);

	my $pd = Padre::Browser::PseudoPerldoc->new( args => \@args );
	SCOPE: {
		local *STDERR = IO::Scalar->new;
		local *STDOUT = IO::Scalar->new;
		eval { $pd->process };
	}

	return unless -s $tempfile;

	my $pa = Pod::Abstract->load_file($tempfile);
	close $fh;
	unlink($tempfile);

	my $doc = Padre::Browser::Document->new( body => $pa->pod );
	$doc->mimetype('application/x-pod');
	my $title_from = $hints->{title_from_section} || 'NAME';
	my $name;
	if (   ($name) = $pa->select("/head1[\@heading =~ {$title_from}]")
		or ($name) = $pa->select("/head1") )
	{
		my $text = $name->text;
		my ($module) = $text =~ /([^\s]+)/g;
		$doc->title($module);
	} elsif ( ($name) = $pa->select("//item") ) {
		my $text = $name->pod;
		my ($item) = $text =~ /=item\s+([^\s]+)/g;
		$doc->title($item);
	}

	unless ( $pa->select('/pod')
		|| $pa->select('//item')
		|| $pa->select('//head1') )
	{
		warn "$ref has no pod in" . $pa->ptree;

		# Unresolvable ?
		return;
	}

	return $doc;

}

sub generate {
	my $self = shift;
	my $doc  = shift;
	$doc->mimetype('application/x-pod');
	return $doc;
	#### TO DO , pod extract / pod tidy ?

	# (Ticket #671)
}

sub render {
	my $self = shift;
	my $doc  = shift;
	my $data = '';
	return if not $doc;
	my $pod = IO::Scalar->new( \$doc->body );
	my $out = IO::Scalar->new( \$data );
	my $v   = Pod::Simple::XHTML->new;
	$v->perldoc_url_prefix('perldoc:');
	$v->output_fh($out);
	$v->parse_file($pod);
	my $response = Padre::Browser::Document->new;
	$response->body( ${ $out->sref } );
	$response->mimetype('text/xhtml');
	$response->title( $doc->title );
	return $response;
}

# Utility function , really wants to be inside a class like
# URI::perldoc ??
sub split_link {
	my $query = shift;
	my ( $doc, $section ) = split /\//, $query, 2; # was m|([^/]+)/?+(.*+)|;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
