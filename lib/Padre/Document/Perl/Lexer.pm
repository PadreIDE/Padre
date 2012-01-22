package Padre::Document::Perl::Lexer;

use 5.008;
use strict;
use warnings;
use PPI::Document  ();
use PPI::Dumper    ();
use Text::Balanced ();
use Padre::Logger;

our $VERSION = '0.94';

sub class_to_color {
	my $class  = shift;
	my $css    = class_to_css($class);
	my %colors = (
		'keyword'       => 4, # dark green
		'structure'     => 6,
		'core'          => 1, # red
		'pragma'        => 7, # purple
		'Whitespace'    => 0,
		'Structure'     => 0,
		'Number'        => 1,
		'Float'         => 1,
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
		'Command'       => 0,
	);

	if ( not defined $colors{$css} ) {
		warn "No color defined for '$css' or '$class'\n";
	}
	return $colors{$css};
}

sub colorize {
	my $class = shift;

	TRACE("Lexer colorize called") if DEBUG;

	my $doc    = Padre::Current->document;
	my $editor = $doc->editor;

	# start and end position for styling, as sent from Wx::STC
	# the algorithm used by Wx::STC to determine what needs styling
	# is not precise enough for our need, but is a good starting point
	my ( $start_pos, $end_pos ) = @_;
	$start_pos ||= 0;
	$end_pos   ||= $editor->GetLength;

	my ($text,              # the text that we will send to PPI for parsing
		$start_line,        # number of first line of text to parse and style
		$end_line,          # number of last line of text to parse and style
		$styling_start_pos, # number of first character to parse and style
		$styling_end_pos,   # number of last character to parse and style
		$line_count,        # number of lines within the document
		$last_char,         # index of the last character in the file
	);

	# convert start and end position to start of first line and end of last line
	# rather than starting to parse and style from the position sent by Wx::STC,
	# we will shift the start and end position to the start of the first line and
	# end of the last line respectively
	$start_line        = $editor->LineFromPosition($start_pos);
	$end_line          = $editor->LineFromPosition($end_pos);
	$styling_start_pos = $editor->PositionFromLine($start_line);
	$styling_end_pos   = $editor->GetLineEndPosition($end_line);
	$line_count        = $editor->GetLineCount;
	$last_char         = $editor->GetLineEndPosition( $line_count - 1 );
	my $inital_text = $editor->GetTextRange( $start_pos, $end_pos );

	# basically we let PPI start parsing the text within the start and end
	# positions we just determined, unless there is a chance that our start
	# or end position is within some multiline token - a quotelike expression
	# or POD

	# this check is not necessary if we are on the first line of text
	if ( $start_line > 0 ) {

		# get first char on the preceding line, but skip newline symbols
		my $previous_char = $styling_start_pos - 1;
		while ( $editor->GetCharAt($previous_char) == 10 or $editor->GetCharAt($previous_char) == 13 ) {
			$previous_char--;
			last if $previous_char <= 1;
		}
		$previous_char--;

		if ( $previous_char > 0 ) {

			# get the start position of the previous token
			# NOTE TO SELF: why did I have to decrement $previous_char again?
			my $previous_style = $editor->GetStyleAt( $previous_char-- );

			my $start_of_previous_token = $previous_char;

			while ( $editor->GetStyleAt($start_of_previous_token) == $previous_style ) {
				$start_of_previous_token--;
				last if $start_of_previous_token <= 0;
			}
			$start_of_previous_token++;

			# get the text of the previous token
			my $prev_token_text = $editor->GetTextRange( $start_of_previous_token, $styling_start_pos - 1 );

			my $prev_ppi_doc = PPI::Document->new( \$prev_token_text );

			if ($prev_ppi_doc) {

				# check if the previous token is a quotelike
				my @tokens     = $prev_ppi_doc->tokens;
				my $prev_token = $tokens[-1];

				if (   $prev_token->isa("PPI::Token::Quote")
					or $prev_token->isa("PPI::Token::QuoteLike")
					or $prev_token->isa("PPI::Token::Regexp") )
				{

					# check if the quotelike token is complete
					if ( !Text::Balanced::extract_quotelike( $prev_token->content ) ) {

						# if the token beore the text we are to parse and style
						# is an unfinished quotelike expression, include it
						# in the text to parse and style
						$styling_start_pos = $start_of_previous_token;
					}
				} elsif ( $prev_token->isa("PPI::Token::Pod") ) {

					# ditto for pod
					$styling_start_pos = $start_of_previous_token;
				}
			}
		}
	}

	# ditto for the token after
	if ( $styling_end_pos < $last_char ) {
		my $next_char = $styling_end_pos + 1;
		while ( $editor->GetCharAt($next_char) == 10 or $editor->GetCharAt($next_char) == 13 ) {
			$next_char++;
			last if $next_char >= $last_char;
		}

		if ( $next_char < $last_char ) {
			my $next_style = $editor->GetStyleAt($next_char);
			if ( $next_style == 9 or $next_style == 2 ) {
				$styling_end_pos = $last_char;
			} else {
				my $end_of_next_token = $next_char;

				while ( $editor->GetStyleAt($end_of_next_token) == $next_style ) {
					$end_of_next_token++;
					last if $end_of_next_token == $last_char;
				}
				$end_of_next_token--;

				my $next_token_text = $editor->GetTextRange( $styling_end_pos + 1, $end_of_next_token );

				my $next_ppi_doc = PPI::Document->new( \$next_token_text );

				if ($next_ppi_doc) {

					my @tokens     = $next_ppi_doc->tokens;
					my $next_token = $tokens[0];

					if ($next_token
						and (  $next_token->isa("PPI::Token::Quote")
							or $next_token->isa("PPI::Token::QuoteLike")
							or $next_token->isa("PPI::Token::Regexp")
							or $next_token->isa("PPI::Token::Pod") )
						)
					{
						$styling_end_pos = $end_of_next_token;
					}
				}
			}
		}
	}

	# check if we have to style it all
	if ( $end_pos and $doc->{_is_colorized} ) {
		$text = $editor->GetTextRange( $styling_start_pos, $styling_end_pos );
		clear_style( $styling_start_pos, $styling_end_pos );
	} else {
		do_full_styling();
		return;
	}

	return unless $text;

	# now that we have determined the proper starting position,
	# feed the text to PPI
	my $ppi_doc = PPI::Document->new( \$text );

	if ($ppi_doc) {

		my @tokens = $ppi_doc->tokens;
		$ppi_doc->index_locations;

		my ( @prepared_extra_tokens, @prepared_tokens );

		# check to see if the last token is quotelike or pod
		my $last_token = $tokens[-1];
		if (   $last_token->isa("PPI::Token::Quote")
			or $last_token->isa("PPI::Token::QuoteLike")
			or $last_token->isa("PPI::Token::Regexp") )
		{
			if ( !Text::Balanced::extract_quotelike( $last_token->content ) ) {

				# get the position at which this token starts
				my ( $row, $rowchar, $col ) = @{ $last_token->location };
				my $new_start_pos = ( $editor->PositionFromLine( $start_line + $row - 1 ) + $rowchar - 1 );

				# get the line at which it ends
				my $token_end_line = ( $editor->LineFromPosition( $new_start_pos + $last_token->length ) );

				# get the next up to 50 lines
				my $new_end_pos = $editor->GetLineEndPosition( $token_end_line + 50 );

				if ( $new_end_pos > $new_start_pos ) {
					my $extra_text = $editor->GetTextRange( $new_start_pos, $new_end_pos );
					clear_style( $new_start_pos, $new_end_pos );

					# parse from start of this token
					my $extra_ppi_doc = PPI::Document->new( \$extra_text );
					my $dumper        = PPI::Dumper->new($extra_ppi_doc);

					my @extra_tokens = $extra_ppi_doc->tokens;
					$extra_ppi_doc->index_locations;

					@prepared_extra_tokens = prepare_tokens( $new_start_pos, @extra_tokens );

					# remove the last token since it is included in the extra tokens

					pop @tokens;
				}
			}
		} elsif ( $last_token->isa("PPI::Token::Pod") ) {

			# get the position at which this token starts
			#my ($row, $rowchar, $col) = @{ $last_token->location };
			#my $token_start_line = $start_line+$row-1;
			#my $new_start_pos = ($editor->PositionFromLine($token_start_line)+ $rowchar-1);

			# get the line at which it ends
			#my $token_end_line = ($editor->LineFromPosition($new_start_pos + $last_token->length));

			my @prepared_pod_token = prepare_tokens( $styling_start_pos, $last_token );
			my $new_start_pos      = $prepared_pod_token[0]->{start};
			my $token_start_line   = $editor->LineFromPosition($new_start_pos);
			my $token_end_line     = $editor->LineFromPosition( $new_start_pos + $prepared_pod_token[0]->{length} );

			# if we are in the first line of pod, start searching for the next line;
			# otherwise start searching from the last line of the pod token
			my $start_search_for_pod_end = $token_end_line;
			$start_search_for_pod_end++ if $token_end_line == $token_start_line;

			my $pod_end = $start_search_for_pod_end;

			while ( my $pod_last_line = $editor->GetLine($pod_end) ) {
				last if $pod_last_line =~ /^=cut\s/;
				$pod_end++;
			}
			$pod_end = $last_char if $pod_end > $last_char;

			my $extra_text = $editor->GetTextRange( $new_start_pos, $editor->GetLineEndPosition($pod_end) );
			clear_style( $new_start_pos, $editor->GetLineEndPosition($pod_end) );

			# parse from start of this token
			my $extra_ppi_doc = PPI::Document->new( \$extra_text );

			my @extra_tokens = $extra_ppi_doc->tokens;
			$extra_ppi_doc->index_locations;

			@prepared_extra_tokens = prepare_tokens( $new_start_pos, $extra_tokens[0] );
			pop @tokens;
		}

		@prepared_tokens = prepare_tokens( $styling_start_pos, @tokens );

		do_styling( @prepared_tokens, @prepared_extra_tokens );
	}
}

sub prepare_tokens {
	my ( $offset, @tokens ) = @_;

	my $doc    = Padre::Current->document;
	my $editor = $doc->editor;

	my @prepared_tokens;

	my $start_line             = $editor->LineFromPosition($offset);
	my $offset_from_start_line = ( $offset - $editor->PositionFromLine($start_line) );

	foreach my $t (@tokens) {
		my ( $row, $rowchar, $col ) = @{ $t->location };

		if ( $row == 1 ) { $rowchar += $offset_from_start_line; }

		my $start     = ( $editor->PositionFromLine( $start_line + $row - 1 ) + $rowchar - 1 );
		my $content   = $t->content;
		my $new_lines = ( $content =~ s/\n/\n/gs );
		my %token     = (
			start  => $start,
			length => ( $t->length + $new_lines ),
			color  => class_to_color($t),
		);

		# workarounds for a bug in PPI ?
		if ( $t->isa('PPI::Token::Comment')
			and ( $start == 1 or $editor->GetCharAt( $start - 1 ) == 10 or $editor->GetCharAt( $start - 1 ) == 13 ) )
		{
			$token{length}--;
		}

		# to color the first # character in the whole document (the sh-bang):
		if ( $start == 1 ) {
			$token{start} = 0;
		}

		#print "$offset $start $token{length} $token{color} '$t' " . ref($t) . "\n" if $token{start} < 180;

		push @prepared_tokens, \%token;
	}

	return @prepared_tokens;
}

sub clear_style {
	my ( $styling_start_pos, $styling_end_pos ) = @_;

	my $doc    = Padre::Current->document;
	my $editor = $doc->editor;

	foreach my $i ( 0 .. 31 ) {
		$editor->StartStyling( $styling_start_pos, $i );
		$editor->SetStyling( $styling_end_pos - $styling_start_pos, 0 );
	}
}

sub do_full_styling {
	my $doc    = Padre::Current->document;
	my $editor = $doc->editor;

	$editor->remove_color;
	my $text = $doc->text_get;
	return unless $text;
	my $ppi_doc = PPI::Document->new( \$text );
	my @tokens  = $ppi_doc->tokens;
	$ppi_doc->index_locations;
	my @prepared_tokens = prepare_tokens( 1, @tokens );
	do_styling(@prepared_tokens);
	$doc->{_is_colorized} = 1;
}

sub do_styling {
	my $doc    = Padre::Current->document;
	my $editor = $doc->editor;

	foreach my $t (@_) {
		$editor->StartStyling( $t->{start}, $t->{color} || 0 );
		$editor->SetStyling( $t->{length}, $t->{color} || 0 );
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
	return $css;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
