package Padre::Document::Perl::Autocomplete;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.85';

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
	my $prefix = shift;
	my $text   = shift;
	my $parser = shift;

	if ( $prefix =~ /([\$\@\%\*])(\w+(?:::\w+)*)$/ ) {
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
				$tag = $parser->findNextTag();
			}
			return ( length($prefix), @words );
		}
	}

	# check for hashs
	elsif ( $prefix =~ /(\$\w+(?:\-\>)?)\{([\'\"]?)([\$\&]?\w*)$/ ) {
		my $hashname   = $1;
		my $textmarker = $2;
		my $keyprefix  = $3;

		my %words;
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
	elsif ( $prefix =~ /(?![\$\@\%\*])(\w+(?:::\w+)*)\s*->\s*(\w*)$/ ) {
		my $class  = $1;
		my $prefix = $2;
		$prefix = '' if not defined $prefix;
		if ( defined $parser ) {
			my $tag = ( $prefix eq '' ) ? $parser->firstTag() : $parser->findTag( $prefix, partial => 1 );
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
				$tag = ( $prefix eq '' ) ? $parser->nextTag() : $parser->findNextTag();
			}
			return ( length($prefix), @words );
		}
	}

	# check for packages
	elsif ( $prefix =~ /(?![\$\@\%\*])(\w+(?:::\w+)*)/ ) {
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
				$tag = $parser->findNextTag();
			}
			return ( length($prefix), @words );
		}
	}

	return;
}



1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
