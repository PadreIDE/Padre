package Padre::Document::Perl::PPILexer;

use 5.008;
use strict;
use warnings;
use Padre::Document ();
use Padre::Util     ();
use Padre::Logger;

our $VERSION = '0.85';

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


	my @tokens = $ppi->tokens;
	$ppi->index_locations;

	foreach my $t (@tokens) {

		my ( $row, $rowchar, $col ) = @{ $t->location };

		my $css = class_to_css($t);

		my $len = $t->length;

		$markup->( $css, $row, $rowchar, $len );
	}
}


sub class_to_css {
	my $Token = shift;

	if ( $Token->isa('PPI::Token::Word') ) {

		# There are some words we can be very confident are
		# being used as keywords
		unless ( $Token->snext_sibling and $Token->snext_sibling->content eq '=>' ) {
			if ( $Token->content =~ /^(?:sub|return)$/ ) {
				return 'keyword';
			} elsif ( $Token->content =~ /^(?:undef|shift|defined|bless)$/ ) {
				return 'core';
			}
		}

		if ( $Token->previous_sibling and $Token->previous_sibling->content eq '->' ) {
			if ( $Token->content =~ /^(?:new)$/ ) {
				return 'core';
			}
		}

		if ( $Token->parent->isa('PPI::Statement::Include') ) {
			if ( $Token->content =~ /^(?:use|no)$/ ) {
				return 'keyword';
			}
			if ( $Token->content eq $Token->parent->pragma ) {
				return 'pragma';
			}
		} elsif ( $Token->parent->isa('PPI::Statement::Variable') ) {
			if ( $Token->content =~ /^(?:my|local|our)$/ ) {
				return 'keyword';
			}
		} elsif ( $Token->parent->isa('PPI::Statement::Compound') ) {
			if ( $Token->content =~ /^(?:if|else|elsif|unless|for|foreach|while|my)$/ ) {
				return 'keyword';
			}
		} elsif ( $Token->parent->isa('PPI::Statement::Package') ) {
			if ( $Token->content eq 'package' ) {
				return 'keyword';
			}
		} elsif ( $Token->parent->isa('PPI::Statement::Scheduled') ) {
			return 'keyword';
		}
	}

	# Normal coloring
	my $css = ref $Token;
	$css =~ s/^.+:://;
	$css;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
