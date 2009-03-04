package Padre::PPI;

use 5.008;
use strict;
use warnings;
use PPI;

our $VERSION = '0.28';





#####################################################################
# Assorted Search Functions

sub find_unmatched_brace {
	$_[1]->isa('PPI::Statement::UnmatchedBrace') and return 1;
	$_[1]->isa('PPI::Structure')                 or return '';
	$_[1]->start and $_[1]->finish               and return '';
	return 1;
}


# scans a document for variable declarations and
# sorts them into three categories:
# lexical (my)
# our (our, doh)
# dynamic (local)
# TODO: add "use vars..." as "package" scope
# Returns a hash reference containing the three category names
# each pointing at a hash which contains '$variablename' => locations.
# locations is an array reference containing one or more PPI-style
# locations. Example:
# {
#   lexical => {
#     '$foo' => [ [ 2, 3, 3], [ 6, 7, 7 ] ],
#   },
#   ...
# }
# Thus, there are two places where a "my $foo" was declared. On line 2 col 3
# and line 6 col 7.
sub get_all_variable_declarations {
	my $document = shift;
	my %vars;

	my $declarations = $document->find(
		sub {
			return 0 unless $_[1]->isa('PPI::Statement::Variable');
			return 1;
		},
	);
	
	my %our;
	my %lexical;
	my %dynamic;
	foreach my $decl (@$declarations) {
		my $type = $decl->type();
		my @vars = $decl->variables;
		my $location = $decl->location;

		my $target_type;

		if ($type eq 'my') {
			$target_type = \%lexical;
		}
		elsif ($type eq 'our') {
			$target_type = \%our;
		}
		elsif ($type eq 'local') {
			$target_type = \%dynamic;
		}

		foreach my $var (@vars) {
			$target_type->{$var} ||= [];
			push @{$target_type->{$var}}, $location;
		}
	}
	
	return({ our => \%our, lexical => \%lexical, dynamic => \%dynamic });
}



#####################################################################
# Stuff that should be in PPI itself

sub element_depth {
	my $cursor = shift;
	my $depth  = 0;
	while ( $cursor = $cursor->parent ) {
		$depth += 1;
	}
	return $depth;
}

# This does not guarantee a match: the location of
# a token is only the first character
# TODO: PPIx::IndexOffsets or something similar might help.
# TODO: See the 71... tests. If we don#t flush locations there, this breaks.
sub find_token_at_location {
	my $document = shift;
	my $location = shift;
	
	if (not defined $document
	    or not $document->isa('PPI::Document')
	    or not defined $location
	    or not ref($location) eq 'ARRAY') {
		require Carp;
		Carp::croak("find_token_at_location() requires a PPI::Document and a PPI-style location is arguments");
	}

	$document->index_locations();

	my $variable_token = $document->find_first(
		sub {
			my $elem = $_[1];
			return 0 if not $elem->isa('PPI::Token');
			my $loc = $elem->location;
			return 0 if $loc->[0] != $location->[0] or $loc->[1] != $location->[1];
			return 1;
		},
	);

	return $variable_token;
}

# given either a PPI::Token::Symbol (i.e. a variable)
# or a PPI::Token which contains something that looks like
# a variable (quoted vars, interpolated vars in regexes...)
# find where that variable has been declared lexically.
# Doesn't find stuff like "use vars...".
sub find_variable_declaration {
	my $cursor   = shift;
	return()
	  if not $cursor or not $cursor->isa("PPI::Token");
	my ($varname, $token_str);
	if ($cursor->isa("PPI::Token::Symbol")) {
		$varname = $cursor->canonical;
		$token_str = $cursor->content;
	}
	else {
		my $content = $cursor->content;
		if ($content =~ /([\$@%*][\w:']+)/) {
			$varname = $1;
			$token_str = $1;
		}
	}
	return()
	  if not defined $varname;

	my $document = $cursor->top();
	my $declaration;
	while ( $cursor = $cursor->parent ) {
		last if $cursor == $document;
		if ($cursor->isa("PPI::Structure::Block")) {
			my @elems = $cursor->elements;
			foreach my $elem (@elems) {
				if ($elem->isa("PPI::Statement::Variable")
				    and grep {$_ eq $varname} $elem->variables) {
					$declaration = $elem;
					last;
				}
			}
			last if $declaration;
		}
	} # end while not top level

	return $declaration;
}


1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
