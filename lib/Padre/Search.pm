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

This is the Padre Search API. It allows the creation of abstract objects
object that can independantly search and/or replace in an editor object.

=head2 METHODS

=cut

use strict;
use warnings;
use Encode     ();
use List::Util ();
use Params::Util '_INSTANCE';

our $VERSION = '0.43';

use Class::XSAccessor getters => {
	find_term    => 'find_term',
	find_case    => 'find_case',
	find_regex   => 'find_regex',
	find_reverse => 'find_reverse',
	replace_term => 'replace_term',
	search_regex => 'search_regex',
};

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	unless ( defined $self->find_term ) {
		die("Did not provide 'find_term' search term");
	}
	unless ( length $self->find_term ) {

		# Pointless zero-length search
		return undef;
	}
	unless ( defined $self->find_case ) {
		$self->{find_case} = $self->config->find_case;
	}
	unless ( defined $self->find_regex ) {
		$self->{find_regex} = $self->config->find_regex;
	}
	unless ( defined $self->find_reverse ) {
		$self->{find_reverse} = $self->config->find_reverse;
	}

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
	$self->{search_regex} = eval { $self->find_case ? qr/$term/m : qr/$term/mi };
	return undef if $@;

	return $self;
}

sub config {
	my $self = shift;
	unless ( defined $self->{config} ) {
		$self->{config} = Padre::Current->config;
	}
	return $self->{config};
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

	# Replace the currently selected match
	$self->replace(@_);

	# Select and move to the next match
	if ( $self->find_reverse ) {
		return $self->search_down(@_);
	} else {
		return $self->search_up(@_);
	}
}

sub replace_previous {
	my $self = shift;

	# Replace the currently selected match
	$self->replace(@_);

	# Select and move to the next match
	if ( $self->find_reverse ) {
		return $self->search_up(@_);
	} else {
		return $self->search_down(@_);
	}
}





#####################################################################
# Content Abstraction

sub search_down {
	my $self = shift;
	if ( _INSTANCE( $_[0], 'Padre::Wx::Editor' ) ) {
		return $self->editor_search_down(@_);
	}
	die("Missing or invalid content object to search in");
}

sub search_up {
	my $self = shift;
	if ( _INSTANCE( $_[0], 'Padre::Wx::Editor' ) ) {
		return $self->editor_search_up(@_);
	}
	die("Missing or invalid content object to search in");
}

sub replace {
	my $self = shift;
	if ( _INSTANCE( $_[0], 'Padre::Wx::Editor' ) ) {
		return $self->editor_replace(@_);
	}
	die("Missing or invalid content object to search in");
}

sub replace_all {
	my $self = shift;
	if ( _INSTANCE( $_[0], 'Padre::Wx::Editor' ) ) {
		return $self->editor_replace_all(@_);
	}
	die("Missing or invalid content object to search in");
}

sub count_all {
	my $self = shift;
	if ( _INSTANCE( $_[0], 'Padre::Wx::Editor' ) ) {
		return $self->editor_count_all(@_);
	}
	die("Missing or invalid ccontent object to search in");
}





#####################################################################
# Editor Interaction

sub editor_search_down {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE( $editor, 'Padre::Wx::Editor' ) ) {
		die("Failed to provide editor object to search in");
	}

	# Execute the search and move to the resulting location
	my ( $start, $end, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection,
	);
	return unless defined $start;

	# Highlight the found item
	$editor->SetSelection( $start, $end );
	return 1;
}

sub editor_search_up {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE( $editor, 'Padre::Wx::Editor' ) ) {
		die("Failed to provide editor object to search in");
	}

	# Execute the search and move to the resulting location
	my ( $start, $end, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection,
		'backwards'
	);
	return unless defined $start;

	# Highlight the found item
	$editor->SetSelection( $start, $end );
	return 1;
}

sub editor_replace {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE( $editor, 'Padre::Wx::Editor' ) ) {
		die("Failed to provide editor object to replace in");
	}

	# Execute the search and move to the resulting location
	my ( $start, $end, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection,
	);

	# If they match replace it
	if ( defined $start and $start == 0 and $end == $editor->GetLength ) {
		$editor->ReplaceSelection( $self->replace_text );
		return 1;
	} else {
		return 0;
	}
}

sub editor_replace_all {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE( $editor, 'Padre::Wx::Editor' ) ) {
		die("Failed to provide editor object to replace in");
	}

	# Execute the search for all matches
	my ( undef, undef, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
	);

	# Replace all matches as a single undo
	if (@matches) {
		my $replace = $self->replace_text;
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

sub editor_count_all {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE( $editor, 'Padre::Wx::Editor' ) ) {
		die("Failed to provide editor object to replace in");
	}

	# Execute the search for all matches
	my ( undef, undef, @matches ) = $self->matches(
		$editor->GetTextRange( 0, $editor->GetLength ),
		$self->search_regex,
		$editor->GetSelection,
	);

	return scalar @matches;
}





#####################################################################
# Core Search

=pod

=head2 matches

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
	my $regex   = shift;
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
		$pair = List::Util::first { $to > $_->[1] } reverse @matches;
		$pair = $matches[-1] unless $pair;
	} else {

		# Search forwards
		$pair = List::Util::first { $from < $_->[0] } @matches;
		$pair = $matches[0] unless $pair;
	}

	return ( @$pair, @matches );
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
