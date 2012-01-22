package Padre::Browser::Document;

=pod

=head1 NAME

Padre::Browser::Document - is an afterthought

L<Padre::Browser> began using <Padre::Document> for internal representation
of documents. This module aims to be less costly to serialize.

=head1 CAVEATS

Until this is a better copy of Padre::Document or the similar parts converge,
it will probably change.

=cut

use 5.008;
use strict;
use warnings;
use File::Basename ();

our $VERSION = '0.94';

use Class::XSAccessor {
	constructor => 'new',
	accessors   => {
		mimetype => 'mime_type',
		body     => 'body',
		title    => 'title',
		filename => 'filename',
	},
};

sub load {
	my ( $class, $path ) = @_;
	open( my $file_in, '<', $path ) or die "Failed to load '$path' $!";
	my $body;
	$body .= $_ while <$file_in>;
	close $file_in;
	my $doc = $class->new( body => $body, filename => $path );
	$doc->mimetype( $doc->guess_mimetype );
	$doc->title( $doc->guess_title );
	return $doc;
}

sub guess_title {
	my ($self) = @_;
	if ( $self->filename ) {
		return File::Basename::basename( $self->filename );
	}
	'Untitled';
}

# Yuk .
# This is the primary file extension to mime-type mapping
our %EXT = (
	abc   => 'text/x-abc',
	ada   => 'text/x-adasrc',
	asm   => 'text/x-asm',
	bat   => 'text/x-bat',
	cpp   => 'text/x-c++src',
	css   => 'text/css',
	diff  => 'text/x-patch',
	e     => 'text/x-eiffel',
	f     => 'text/x-fortran',
	htm   => 'text/html',
	html  => 'text/html',
	js    => 'application/javascript',
	json  => 'application/json',
	latex => 'application/x-latex',
	lsp   => 'application/x-lisp',
	lua   => 'text/x-lua',
	mak   => 'text/x-makefile',
	mat   => 'text/x-matlab',
	pas   => 'text/x-pascal',
	pod   => 'text/x-pod',
	php   => 'application/x-php',
	py    => 'text/x-python',
	rb    => 'application/x-ruby',
	sql   => 'text/x-sql',
	tcl   => 'application/x-tcl',
	vbs   => 'text/vbscript',
	patch => 'text/x-patch',
	pl    => 'application/x-perl',
	plx   => 'application/x-perl',
	pm    => 'application/x-perl',
	pod   => 'application/x-perl',
	t     => 'application/x-perl',
	conf  => 'text/plain',
	sh    => 'application/x-shellscript',
	ksh   => 'application/x-shellscript',
	txt   => 'text/plain',
	xml   => 'text/xml',
	yml   => 'text/x-yaml',
	yaml  => 'text/x-yaml',
	'4th' => 'text/x-forth',
	pasm  => 'application/x-pasm',
	pir   => 'application/x-pir',
	p6    => 'application/x-perl6',
);

sub guess_mimetype {
	my ($self) = @_;
	unless ( $self->filename ) {
		return 'application/x-pod';
	}
	my ( $path, $file, $suffix ) = File::Basename::fileparse(
		$self->filename,
		keys %EXT
	);

	my $type =
		exists $EXT{$suffix}
		? $EXT{$suffix}
		: '';
	return $type;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
