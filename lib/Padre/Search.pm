package Padre::Search;

=pod

=head1 NAME

Padre::Search - The Padre Search API

=head2 SYNOPSIS

  # Create the search object
  my $search = Padre::Search->new(
      find_text => 'foo',
  );  
  
  # Execute the search on an editor object
  $search->find_down($editor);

=head2 DESCRIPTION

This is the Padre Search API. It allows the creation of abstract objects
object that can independantly search and/or replace in an editor object.

=head2 METHODS

=cut

use strict;
use warnings;
use Encode       ();
use List::Util   ();
use Params::Util '_INSTANCE';

our $VERSION = '0.36';

use Class::XSAccessor
getters => {
	find_text    => 'find_text',
	find_case    => 'find_case',
	find_regex   => 'find_regex',
	find_reverse => 'find_reverse',
};

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	unless ( defined $self->find_text ) {
		die("Did not provide 'find_text' search term");
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
# Direction Abstraction

sub search_next {
	my $self = shift;
	if ( $self->config->find_reverse ) {
		return $self->search_down(@_);
	} else {
		return $self->search_up(@_);
	}
}

sub search_previous {
	my $self = shift;
	if ( $self->config->find_reverse ) {
		return $self->search_up(@_);
	} else {
		return $self->search_down(@_);
	}
}

sub replace_next {
	my $self = shift;
	if ( $self->config->find_reverse ) {
		return $self->replace_down(@_);
	} else {
		return $self->replace_up(@_);
	}
}

sub replace_previous {
	my $self = shift;
	if ( $self->config->find_reverse ) {
		return $self->replace_up(@_);
	} else {
		return $self->replace_down(@_);
	}
}





#####################################################################
# Search Methods

sub search_down {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE($editor, 'Padre::Wx::Editor') ) {
		die("Failed to provide editor object to search in");
	}
	die "CODE INCOMPLETE";
}

sub search_up {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE($editor, 'Padre::Wx::Editor') ) {
		die("Failed to provide editor object to search in");
	}
	die "CODE INCOMPLETE";
}

sub replace_down {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE($editor, 'Padre::Wx::Editor') ) {
		die("Failed to provide editor object to search in");
	}
	die "CODE INCOMPLETE";
}

sub replace_up {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE($editor, 'Padre::Wx::Editor') ) {
		die("Failed to provide editor object to search in");
	}
	die "CODE INCOMPLETE";
}

sub replace_all {
	my $self   = shift;
	my $editor = shift;
	unless ( _INSTANCE($editor, 'Padre::Wx::Editor') ) {
		die("Failed to provide editor object to search in");
	}
	die "CODE INCOMPLETE";
}





#####################################################################
# The Actual Search

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
	unless ( @matches ) {
		return ( undef, undef );
	}

	my $pair = ();
	my $from = shift;
	my $to   = shift;
	if ( $_[0] ) {
		# Search backwards
		my $pair = List::Util::first { $to > $_->[1] } reverse @matches;
		$pair = $matches[-1] unless $pair;
	} else {
		# Search forwards
		my $pair = List::Util::first { $from < $_->[0] } @matches;
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
