package Padre::Document::Perl::PPILexer;

use 5.008;
use strict;
use warnings;
use Padre::Document ();
use Padre::Util     ();

our $VERSION = '0.42';


sub colorize {
	my $self = shift;

	my $doc = Padre::Current->document;

	Padre::Util::debug("PPILexer colorize called");

	$doc->remove_color;

	my $editor = $doc->editor;
	my $text   = $doc->text_get;
	return unless $text;

	require PPI::Document;
	my $ppi_doc = PPI::Document->new( \$text );
	if ( not defined $ppi_doc ) {
		Padre::Util::debug( 'PPI::Document Error %s', PPI::Document->errstr );
		Padre::Util::debug( 'Original text: %s',      $text );
		return;
	}

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

	my @tokens = $ppi_doc->tokens;
	$ppi_doc->index_locations;
	my $first = $editor->GetFirstVisibleLine;
	my $lines = $editor->LinesOnScreen;

	#print "First $first lines $lines\n";
	foreach my $t (@tokens) {

		#print $t->content;
		my ( $row, $rowchar, $col ) = @{ $t->location };

		#		next if $row < $first;
		#		next if $row > $first + $lines;
		my $css = $self->_css_class($t);

		#		if ($row > $first and $row < $first + 5) {
		#			print "$row, $rowchar, ", $t->length, "  ", $t->class, "  ", $css, "  ", $t->content, "\n";
		#		}
		#		last if $row > 10;
		my $color = $colors{$css};
		if ( not defined $color ) {
			Padre::Util::debug("Missing definition for '$css'\n");
			next;
		}
		next if not $color;

		my $start = $editor->PositionFromLine( $row - 1 ) + $rowchar - 1;
		my $len   = $t->length;

		$editor->StartStyling( $start, $color );
		$editor->SetStyling( $len, $color );
	}
}

sub _css_class {
	my ( $self, $Token ) = @_;
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
		} elsif ( $Token->parent->isa('PPI::Statement::Compond') ) {
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

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
