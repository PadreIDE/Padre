package Padre::Search;

=pod

=head1 NAME

Padre::Search - The Padre Search API

=head2 SYNOPSIS

  # Create the search object
  my $search = Padre::Search->new(
      find_term => 'foo',
  );
  
  # Execute the search on the current editor
  $search->search_next(Padre::Current->editor);

=head2 DESCRIPTION

This is the Padre Search API. It allows the creation of abstract search
object that can independently search and/or replace in an editor object.

=head2 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp         ();
use Encode       ();
use Scalar::Util ();
use List::Util   ();
use Params::Util ();

our $VERSION    = '0.93';
our $COMPATIBLE = '0.93';

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Check params
	unless ( defined $self->find_term ) {
		die "Did not provide 'find_term' search term";
	}
	unless ( length $self->find_term ) {

		# Pointless zero-length search
		return;
	}

	# Apply defaults
	$self->{find_case}    ||= 0;
	$self->{find_regex}   ||= 0;
	$self->{find_reverse} ||= 0;

	# Pre-compile the search
	unless ( defined $self->search_regex ) {
		return;
	}

	return $self;
}

sub find_term {
	$_[0]->{find_term};
}

sub find_case {
	$_[0]->{find_case};
}

sub find_regex {
	$_[0]->{find_regex};
}

sub find_reverse {
	$_[0]->{find_reverse};
}

sub replace_term {
	$_[0]->{replace_term};
}

sub search_regex {
	my $self = shift;

	# Escape the raw search term
	my $term = $self->find_term;
	if ( $self->find_regex ) {

		# Escape non-trailing $ so they won't interpolate
		$term =~ s/\$(?!\z)/\\\$/g;
	} else {

		# Escape everything
		$term = quotemeta $term;
	}

	# Compile the regex
	my $search_regex = eval { $self->find_case ? qr/$term/m : qr/$term/mi };
	return if $@;

	return $search_regex;
}

sub equals {
	my $self   = shift;
	my $search = Params::Util::_INSTANCE(shift, 'Padre::Search') or return;
	return Scalar::Util::refaddr($self) == Scalar::Util::refaddr($search);
}





#####################################################################
# Command Abstraction

sub search_next {
	my $self = shift;
	if ( $self->find_reverse ) {
		return $self->search_up(@_);
	} else {
		return $self->search_down(@_);
	}
}

sub search_previous {
	my $self = shift;
	if ( $self->find_reverse ) {
		return $self->search_down(@_);
	} else {
		return $self->search_up(@_);
	}
}

sub replace_next {
	my $self = shift;
	if ( $self->find_reverse ) {
		return $self->replace_up(@_);
	} else {
		return $self->replace_down(@_);
	}
}

sub replace_previous {
	my $self = shift;
	if ( $self->find_reverse ) {
		return $self->replace_down(@_);
	} else {
		return $self->replace_up(@_);
	}
}





#####################################################################
# Content Abstraction

sub search_down {
	my $self   = shift;
	my $editor = _EDITOR(shift);
	$self->editor_search_down( $editor, @_ );
}

sub search_up {
	my $self   = shift;
	my $editor = _EDITOR(shift);
	$self->editor_search_up( $editor, @_ );
}

sub search_count {
	my $self = shift;
	if ( Params::Util::_INSTANCE( $_[0], 'Padre::Wx::Editor' ) ) {
		return $self->editor_search_count(@_);
	} elsif ( Params::Util::_SCALAR0( $_[0] ) ) {
		return $self->scalar_search_count(@_);
	}
	die "Missing or invalid content object";
}

sub replace {
	my $self   = shift;
	my $editor = _EDITOR(shift);
	$self->editor_replace_down( $editor, @_ );
}

sub replace_down {
	my $self   = shift;
	my $editor = _EDITOR(shift);
	$self->editor_replace_down( $editor, @_ );
}

sub replace_up {
	my $self   = shift;
	my $editor = _EDITOR(shift);
	$self->editor_replace_up( $editor, @_ );
}

sub replace_all {
	my $self = shift;
	if ( Params::Util::_INSTANCE( $_[0], 'Padre::Wx::Editor' ) ) {
		return $self->editor_replace_all(@_);
	} elsif ( Params::Util::_SCALAR0( $_[0] ) ) {
		return $self->scalar_replace_all(@_);
	}
	die "Missing or invalid content object";
}






#####################################################################
# Editor Interaction

sub editor_search_down {
	my $self   = shift;
	my $editor = _EDITOR(shift);

	# Execute the search and move to the resulting location
	my ( $start, $end, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection,
	);
	return unless defined $start;

	# Highlight the found item
	$editor->match( $self, $start, $end );
}

sub editor_search_up {
	my $self   = shift;
	my $editor = _EDITOR(shift);

	# Execute the search and move to the resulting location
	my ( $start, $end, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection,
		'backwards'
	);
	return unless defined $start;

	# Highlight the found item
	$editor->match( $self, $start, $end );
}

sub editor_search_count {
	my $self   = shift;
	my $editor = _EDITOR(shift);

	# Execute the regex search for all matches
	$self->match_count(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
	);
}

sub editor_replace_down {
	my $self   = shift;
	my $editor = _EDITOR(shift);

	# Execute the search so we can establish if we have already
	# selected a match.
	my ( $start, $end, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection,
	);
	return unless @matches;

	# Are we perfectly selecting a match already
	my $selection_start = $editor->GetSelectionStart;
	my $selection_end   = $editor->GetSelectionEnd;
	unless ( $selection_start == $selection_end ) {
		foreach my $i ( 0 .. $#matches ) {
			my $match = $matches[$i];
			next unless $match->[0] == $selection_start;
			next unless $match->[1] == $selection_end;

			# The selection matches, replace it
			$editor->ReplaceSelection( $self->replace_term );

			# Shortcut if there are no more matches
			return unless $#matches;

			# Move to the next match
			if ( $i == $#matches ) {
				# Wrap to the beginning of the document
				$start = $matches[0]->[0];
				$end   = $matches[0]->[1];
			} else {
				my $delta = $editor->GetSelectionEnd - $selection_end;
				my $down  = $matches[$i + 1];
				$start    = $down->[0] + $delta;
				$end      = $down->[1] + $delta;
			}

			last;
		}
	}

	$editor->match( $self, $start, $end );
}

sub editor_replace_up {
	my $self   = shift;
	my $editor = _EDITOR(shift);

	# Execute the search so we can establish if we have already
	# selected a match.
	my ( $start, $end, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection,
	);
	return unless @matches;

	# Are we perfectly selecting a match already
	my $selection_start = $editor->GetSelectionStart;
	my $selection_end   = $editor->GetSelectionEnd;
	unless ( $selection_start == $selection_end ) {
		foreach my $i ( 0 .. $#matches ) {
			my $match = $matches[$i];
			next unless $match->[0] == $selection_start;
			next unless $match->[1] == $selection_end;

			# The selection matches, replace it
			$editor->ReplaceSelection( $self->replace_term );

			# Shortcut if there are no more matches
			return unless $#matches;

			# Move to the next match
			if ( $i == 0 ) {
				# Wrap to the end of the document
				my $delta = $editor->GetSelectionEnd - $selection_end;
				$start = $matches[-1]->[0] + $delta;
				$end   = $matches[-1]->[1] + $delta;
			} else {
				my $up = $matches[$i - 1];
				$start = $up->[0];
				$end   = $up->[1];
			}

			last;
		}
	}

	$editor->match( $self, $start, $end );
}

sub editor_replace_all {
	my $self   = shift;
	my $editor = _EDITOR(shift);

	# Execute the search for all matches
	my ( undef, undef, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection
	);

	# Replace all matches as a single undo
	if (@matches) {
		my $replace = $self->replace_term;
		$editor->BeginUndoAction;
		foreach my $match ( reverse @matches ) {
			$editor->SetTargetStart( $match->[0] );
			$editor->SetTargetEnd( $match->[1] );
			$editor->ReplaceTarget($replace);
		}
		$editor->EndUndoAction;
	}

	# Return the number of matches we replaced
	return scalar @matches;
}





#####################################################################
# Scalar Interaction

sub scalar_search_count {
	my $self   = shift;
	my $scalar = shift;
	unless ( Params::Util::_SCALAR0($scalar) ) {
		die "Failed to provide SCALAR to count in";
	}

	# Execute the regex search for all matches
	$self->match_count(
		$$scalar,
		$self->search_regex,
	);
}

sub scalar_replace_all {
	my $self   = shift;
	my $scalar = shift;
	unless ( Params::Util::_SCALAR0($scalar) ) {
		die "Failed to provide SCALAR to count in";
	}

	# Prepare the search and replace
	my $search  = $self->search_regex;
	my $replace = $self->replace_term;

	# Do the replacement
	my $count = $$scalar =~ s/$search/$replace/g;

	# Return the replace count
	return $count;
}





#####################################################################
# Core Search Methods

=pod

=head2 matches

  my ($first_char, $last_char, @all) = $search->matches(
      $search_text,
      $search_regexp,
      $from,
      $to,
      $reverse,
  );

Parameters:

* The text in which we need to search

* The regular expression

* The offset within the text where we the last match started so the next
  forward match must start after this.

* The offset within the text where we the last match ended so the next
  backward match must end before this.

* backward bit (1 = search backward, 0 = search forward)

=cut

sub matches {
	my $self = shift;
	die "missing parameters" if @_ < 4;

	# Searches run in unicode
	my $text = Encode::encode( 'utf-8', shift );

	# Find all matches for the regex
	my $regex = shift;
	$regex = Encode::encode( 'utf-8', $regex );
	my @matches = ();
	while ( $text =~ /$regex/g ) {
		push @matches, [ $-[0], $+[0] ];
	}
	unless (@matches) {
		return ( undef, undef );
	}

	my $pair = [];
	my $from = shift || 0;
	my $to   = shift || 0;
	if ( $_[0] ) {

		# Search backwards
		$pair = List::Util::first { $from >= $_->[1] } reverse @matches;
		$pair = $matches[-1] unless $pair;
	} else {

		# Search forwards
		$pair = List::Util::first { $to <= $_->[0] } @matches;
		$pair = $matches[0] unless $pair;
	}

	return ( @$pair, @matches );
}

# NOTE: This current fails to work with multi-line search expressions
sub match_lines {
	my $self  = shift;
	my @lines = split /\n/, Encode::encode( 'utf-8', shift );
	my $regex = shift;

	# Apply the search regex as a filter
	return map { [ $_ + 1, $lines[$_] ] } grep { $lines[$_] =~ /$regex/ } ( 0 .. $#lines );
}

sub match_count {
	my $self  = shift;
	my $text  = Encode::encode( 'utf-8', shift );
	my $regex = shift;
	my $count = () = $text =~ /$regex/g;
	return $count;
}





######################################################################
# Support Functions

sub _EDITOR {
	unless ( Params::Util::_INSTANCE($_[0], 'Padre::Wx::Editor') ) {
		Carp::croak("Missing or invalid Padre::Ex::Editor param");
	}
	return $_[0];
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
