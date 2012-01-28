package Padre::Comment;

=pod

=head1 NAME

Padre::Comment - Padre Comment Support Library

=head1 DESCRIPTION

This module provides objects which represent a logical comment style for
a programming language and implements a range of logic to assist in
locating, counting, filtering, adding and removing comments in a document.

Initially, however, it only acts as a central storage location for the
comment styles of supported mime types.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;

our $VERSION    = '0.95';
our $COMPATIBLE = '0.95';

my %MIME = (
	'text/x-abc'                => '\\',
	'text/x-actionscript'       => '//',
	'text/x-adasrc'             => '--',
	'text/x-asm'                => '#',
	'text/x-bat'                => 'REM',
	'application/x-bibtex'      => '%',
	'application/x-bml'         => [ '<?_c', '_c?>' ],
	'text/x-csrc'               => '//',
	'text/x-cobol'              => '      *',
	'text/x-config'             => '#',
	'text/css'                  => [ '/*', '*/' ],
	'text/x-eiffel'             => '--',
	'text/x-forth'              => '\\',
	'text/x-fortran'            => '!',
	'text/x-haskell'            => '--',
	'application/x-latex'       => '%',
	'application/x-lisp'        => ';',
	'text/x-lua'                => '--',
	'text/x-makefile'           => '#',
	'text/x-matlab'             => '%',
	'text/x-pascal'             => [ '{', '}' ],
	'application/x-pasm'        => '#',
	'application/x-perl'        => '#',
	'application/x-perl6'       => '#',
	'application/x-pir'         => '#',
	'text/x-perltt'             => [ '<!--', '-->' ],
	'application/x-php'         => '#',
	'text/x-pod'                => '#',
	'text/x-povray'             => '//',
	'text/x-python'             => '#',
	'text/x-r'                  => '#',
	'application/x-ruby'        => '#',
	'text/sgml'                 => [ '<!--', '-->' ],
	'application/x-shellscript' => '#',
	'text/x-sql'                => '--',
	'application/x-tcl'         => [ 'if 0 {', '}' ],
	'text/vbscript'             => "'",
	'text/xml'                  => [ '<!--', '-->' ],
	'text/x-yaml'               => '#',
);





######################################################################
# Static Methods

=pod

=head2 types

  my @registered = Padre::Comment->types;

The C<types> method returns the list of all registered MIME types that
have comments distinct from their parent supertypes.

=cut

sub types {
	keys %MIME;
}

=pod

=head2 find

  my $comment = Padre::Comment->find('application/x-perl');

The C<find> method returns the comment string for a provided mime type.

This method returns only the specific string and does not follow the
superpath of the mime type. For access to the comment in a high quality
manner you should obtain the comment via the mime type object as follows:

  my $comment = Padre::MIME->find('application/x-csharp')->comment;

Returns a comment string, or C<undef> if the mime type does not have a
distinct comment string.

=cut

sub find {
	my $class = shift;
	my $type  = shift;
	return $MIME{$type};
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut
