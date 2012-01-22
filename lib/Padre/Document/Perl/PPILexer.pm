package Padre::Document::Perl::PPILexer;

use 5.008;
use strict;
use warnings;
use Padre::Document ();
use Padre::Util     ();
use Padre::Logger;

our $VERSION = '0.94';

sub colorize {
	TRACE("PPILexer colorize called") if DEBUG;
	my $self = shift;

	my $document = Padre::Current->document;
	my $editor   = $document->editor;
	my $text     = $document->text_get or return;

	# Flush old colouring
	$editor->remove_color;

	lexer( $text, sub { put_color( $editor, @_ ) } );

	return;
}

sub get_colors {

	my %colors = (
		keyword      => 4, # dark green
		structure    => 6,
		core         => 1, # red
		pragma       => 7, # purple
		'Whitespace' => 0,
		'Structure'  => 0,

		'Number' => 1,
		'Float'  => 1,

		'HereDoc'       => 4,
		'Data'          => 4,
		'Operator'      => 6,
		'Comment'       => 2, # it's good, it's green
		'Pod'           => 2,
		'End'           => 2,
		'Label'         => 0,
		'Word'          => 0, # stay the black
		'Quote'         => 9,
		'Single'        => 9,
		'Double'        => 9,
		'Backtick'      => 9,
		'Interpolate'   => 9,
		'QuoteLike'     => 7,
		'Regexp'        => 7,
		'Words'         => 7,
		'Readline'      => 7,
		'Match'         => 3,
		'Substitute'    => 5,
		'Transliterate' => 5,
		'Separator'     => 0,
		'Symbol'        => 0,
		'Prototype'     => 0,
		'ArrayIndex'    => 0,
		'Cast'          => 0,
		'Magic'         => 0,
		'Octal'         => 0,
		'Hex'           => 0,
		'Literal'       => 0,
		'Version'       => 0,
	);

	return \%colors;
}

sub put_color {
	my ( $editor, $css, $row, $rowchar, $len ) = @_;

	my $color = get_colors()->{$css};
	if ( not defined $color ) {
		TRACE("Missing definition for '$css'\n") if DEBUG;
		return;
	}
	return if not $color;

	my $start = $editor->PositionFromLine( $row - 1 ) + $rowchar - 1;
	$editor->StartStyling( $start, $color );
	$editor->SetStyling( $len, $color );

	return;
}

sub lexer {
	my $text   = shift;
	my $markup = shift;

	# Parse the file
	require PPI::Document;
	my $ppi = PPI::Document->new( \$text );
	if ( not defined $ppi ) {
		if (DEBUG) {
			TRACE( 'PPI::Document Error %s', PPI::Document->errstr );
			TRACE( 'Original text: %s',      $text );
		}
		return;
	}

	require PPIx::EditorTools::Lexer;
	PPIx::EditorTools::Lexer->new->lexer(
		ppi         => $ppi,
		highlighter => $markup,
	);

	return;
}



1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
