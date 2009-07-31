package Padre::DocBrowser::POD;

use 5.008;
use strict;
use warnings;
use Config     ();
use IO::Scalar ();
use Params::Util qw( _INSTANCE );
use Pod::Simple::XHTML          ();
use Pod::Abstract               ();
use Padre::DocBrowser::document ();
use File::Temp                  ();

our $VERSION = '0.42';

use Class::XSAccessor constructor => 'new', getters => {
	get_provider => 'provider',
};

sub provider_for {
	'application/x-perl', 'application/x-pod',;
}

# uri schema like http:// pod:// blah://
sub accept_schemes {
	'perldoc';
}

sub viewer_for {
	'application/x-pod',;
}

sub resolve {
	my $self  = shift;
	my $ref   = shift;
	my $hints = shift;

	my $query = $ref;

	if ( _INSTANCE( $ref, 'URI' ) ) {
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
		$query
	);

	my $pd = Padre::DocBrowser::pseudoPerldoc->new( args => \@args );
	{
		local *STDERR = IO::Scalar->new;
		local *STDOUT = IO::Scalar->new;
		eval { $pd->process() };
	}

	return unless -s $tempfile;

	my $pa = Pod::Abstract->load_file($tempfile);
	close $fh;
	unlink($tempfile);

	my $doc = Padre::DocBrowser::document->new( body => $pa->pod );
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

# Even worse than monkey patching , copy paste from Pod::Perldoc w/ edits
# to avoid untrappable calls to 'exit'
sub process {

	# if this ever returns, its retval will be used for exit(RETVAL)

	my $self = shift;

	# TODO: make it deal with being invoked as various different things
	#  such as perlfaq".

	return $self->usage_brief unless @{ $self->{'args'} };
	$self->pagers_guessing;
	$self->options_reading;
	$self->aside( sprintf "$0 => %s v%s\n", ref($self), $self->VERSION );
	$self->drop_privs_maybe;
	$self->options_processing;

	# Hm, we have @pages and @found, but we only really act on one
	# file per call, with the exception of the opt_q hack, and with
	# -l things

	$self->aside("\n");

	my @pages;
	$self->{'pages'} = \@pages;
	if    ( $self->opt_f ) { @pages = ("perlfunc") }
	elsif ( $self->opt_q ) { @pages = ( "perlfaq1" .. "perlfaq9" ) }
	else                   { @pages = @{ $self->{'args'} }; }

	return $self->usage_brief unless @pages;

	$self->find_good_formatter_class();
	$self->formatter_sanity_check();

	$self->maybe_diddle_INC();

	# for when we're apparently in a module or extension directory

	my @found = $self->grand_search_init( \@pages );
	return unless @found;

	if ( $self->opt_l ) {
		print join( "\n", @found ), "\n";
		return;
	}

	$self->tweak_found_pathnames( \@found );
	$self->assert_closing_stdout;
	return $self->page_module_file(@found) if $self->opt_m;

	return $self->render_and_page( \@found );
}
1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
