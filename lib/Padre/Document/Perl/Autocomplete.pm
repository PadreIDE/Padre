package Padre::Document::Perl::Autocomplete;

use 5.008;
use strict;
use warnings;

use List::Util ();

our $VERSION = '0.94';

# Experimental package. The API needs a lot of refactoring
# and the whole thing needs a lot of tests


sub new {
	my $class = shift;

	# Padre has its own defaults for each parameter but this code
	# might serve other purposes as well
	my %args = (
		minimum_prefix_length        => 1,
		maximum_number_of_choices    => 20,
		minimum_length_of_suggestion => 3,
		@_
	);

	my $self = bless \%args, $class;
	return $self;
}

# WARNING: This is totally not done, but Gabor made me commit it.
# TO DO:
# a) complete this list
# b) make the path configurable
# c) make the whole thing optional and/or pluggable
# d) make it not suck
# e) make the types of auto-completion configurable
# f) remove the old auto-comp code or at least let the user choose to use the new
#    *or* the old code via configuration
# g) hack STC so that we can get more information in the autocomp. window,
# h) hack STC so we can start populating the autocompletion choices and continue to do so in the background
# i) hack Perl::Tags to be better (including inheritance)
# j) add inheritance support
# k) figure out how to do method auto-comp. on objects
# (Ticket #676)

sub run {
	my $self   = shift;
	my $parser = shift;


	if ( $self->{prefix} =~ /([\$\@\%\*])(\w+(?:::\w+)*)$/ ) {
		my $prefix = $2;
		my $type   = $1;
		if ( defined $parser ) {
			my $tag = $parser->findTag( $prefix, partial => 1 );
			my @words;
			my %seen;
			while ( defined($tag) ) {

				# TO DO check file scope?
				if ( !defined( $tag->{kind} ) ) {

					# This happens with some tagfiles which have no kind
				} elsif ( $tag->{kind} eq 'v' ) {

					# TO DO potentially don't skip depending on circumstances.
					if ( not $seen{ $tag->{name} }++ ) {
						push @words, $tag->{name};
					}
				}
				$tag = $parser->findNextTag;
			}
			return ( length($prefix), @words );
		}
	}

	# check for hashs
	elsif ( $self->{prefix} =~ /(\$\w+(?:\-\>)?)\{([\'\"]?)([\$\&]?\w*)$/ ) {
		my $hashname   = $1;
		my $textmarker = $2;
		my $keyprefix  = $3;

		my %words;
		my $text = $self->{pre_text} . ' ' . $self->{post_text};
		while ( $text =~ /\Q$hashname\E\{(([\'\"]?)\Q$keyprefix\E.+?\2)\}/g ) {
			$words{$1} = 1;
		}

		return (
			length( $textmarker . $keyprefix ),
			sort {
				my $a1 = $a;
				my $b1 = $b;
				$a1 =~ s/^([\'\"])(.+)\1/$2/;
				$b1 =~ s/^([\'\"])(.+)\1/$2/;
				$a1 cmp $b1;
				} ( keys(%words) )
		);

	}

	# check for methods
	elsif ( $self->{prefix} =~ /(?![\$\@\%\*])(\w+(?:::\w+)*)\s*->\s*(\w*)$/ ) {
		my $class  = $1;
		my $prefix = $2;
		$prefix = '' if not defined $prefix;
		if ( defined $parser ) {
			my $tag = ( $prefix eq '' ) ? $parser->firstTag : $parser->findTag( $prefix, partial => 1 );
			my @words;

			# TO DO: INHERITANCE!
			while ( defined($tag) ) {
				if ( !defined( $tag->{kind} ) ) {

					# This happens with some tagfiles which have no kind
				} elsif ( $tag->{kind} eq 's'
					and defined $tag->{extension}{class}
					and $tag->{extension}{class} eq $class )
				{
					push @words, $tag->{name};
				}
				$tag = ( $prefix eq '' ) ? $parser->nextTag : $parser->findNextTag;
			}
			return ( length($prefix), @words );
		}
	}

	# check for packages
	elsif ( $self->{prefix} =~ /(?![\$\@\%\*])(\w+(?:::\w+)*)/ ) {
		my $prefix = $1;

		if ( defined $parser ) {
			my $tag = $parser->findTag( $prefix, partial => 1 );
			my @words;
			my %seen;
			while ( defined($tag) ) {

				# TO DO check file scope?
				if ( !defined( $tag->{kind} ) ) {

					# This happens with some tagfiles which have no kind
				} elsif ( $tag->{kind} eq 'p' ) {

					# TO DO potentially don't skip depending on circumstances.
					if ( not $seen{ $tag->{name} }++ ) {
						push @words, $tag->{name};
					}
				}
				$tag = $parser->findNextTag;
			}
			return ( length($prefix), @words );
		}
	}

	return;
}

sub auto {
	my $self = shift;

	my $nextchar = $self->{nextchar};
	my $prefix   = $self->{prefix};

	$prefix =~ s{^.*?((\w+::)*\w+)$}{$1};

	my $suffix = substr $self->{post_text}, 0, List::Util::min( 15, length $self->{post_text} );
	$suffix = $1 if $suffix =~ /^(\w*)/; # Cut away any non-word chars

	if ( defined($nextchar) ) {
		return if ( length($prefix) + 1 ) < $self->{minimum_prefix_length};
	} else {
		return if length($prefix) < $self->{minimum_prefix_length};
	}


	my $regex;
	eval { $regex = qr{\b(\Q$prefix\E\w+(?:::\w+)*)\b} };
	if ($@) {
		return ("Cannot build regular expression for '$prefix'.");
	}

	my %seen;
	my @words;
	push @words, grep { !$seen{$_}++ } reverse( $self->{pre_text} =~ /$regex/g );
	push @words, grep { !$seen{$_}++ } ( $self->{post_text} =~ /$regex/g );

	if ( @words > $self->{maximum_number_of_choices} ) {
		@words = @words[ 0 .. ( $self->{maximum_number_of_choices} - 1 ) ];
	}

	# Suggesting the current word as the only solution doesn't help
	# anything, but your need to close the suggestions window before
	# you may press ENTER/RETURN.
	if ( ( $#words == 0 ) and ( $prefix eq $words[0] ) ) {
		return;
	}

	# While typing within a word, the rest of the word shouldn't be
	# inserted.
	if ( defined($suffix) ) {
		for ( 0 .. $#words ) {
			$words[$_] =~ s/\Q$suffix\E$//;
		}
	}

	# This is the final result if there is no char which hasn't been
	# saved to the editor buffer until now
	#	return ( length($prefix), @words ) if !defined($nextchar);


	# Finally cut out all words which do not match the next char
	# which will be inserted into the editor (by the current event)
	# and remove all which are too short
	my @final_words;
	for (@words) {

		# Filter out everything which is too short
		next if length($_) < $self->{minimum_length_of_suggestion};

		# Accept everything which has prefix + next char + at least one other char
		# (check only if any char is pending)
		next if defined($nextchar) and ( !/^\Q$prefix$nextchar\E./ );

		# All checks passed, add to the final list
		push @final_words, $_;
	}

	return ( length($prefix), @final_words );
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
