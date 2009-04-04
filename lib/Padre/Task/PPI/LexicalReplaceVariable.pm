
package Padre::Task::PPI::LexicalReplaceVariable;
use strict;
use warnings;

our $VERSION = '0.33';

use base 'Padre::Task::PPI';
use Padre::Wx ();

=pod

=head1 NAME

Padre::Task::PPI::LexicalReplaceVariable - Lexically variable replace using PPI

=head1 SYNOPSIS

  my $replacer = Padre::Task::PPI::LexicalReplaceVariable->new(
          document    => $document_obj,
          location    => [$line, $column], # the position of *any* occurrance of the variable
          replacement => '$foo',
  );
  $replacer->schedule();

=head1 DESCRIPTION

Given a location in the document (line/column), determines the name of the
variable at this position, finds where the variable was defined,
and B<lexically> replaces all occurrances with another variable.

=cut

sub prepare {
	my $self = shift;
	$self->SUPER::prepare(@_);

	# move the document to the main-thread-only storage
	my $mto = $self->{main_thread_only} ||= {};
	$mto->{document} = $self->{document}
		if defined $self->{document};
	delete $self->{document};
	if ( not defined $mto->{document} ) {
		require Carp;
		Carp::croak("Missing Padre::Document::Perl object as {document} attribute of the brace-finder task");
	}

	if ( not defined $self->{replacement} ) {
		require Carp;
		Carp::croak("Need a {replacement}!");
	}

	if ( not defined $self->{location} ) {
		require Carp;
		Carp::croak("Need a {location}!");
	}

	return ();
}

sub process_ppi {

	# find bad braces
	my $self     = shift;
	my $ppi      = shift or return;
	my $location = $self->{location};

	$ppi->flush_locations();    # TODO: PPI bug? This shouldn't be necessary!
	my $token = Padre::PPI::find_token_at_location( $ppi, $location );
	if ( not $token ) {
		$self->{error} = "no token";
		return;
	}

	my $declaration = Padre::PPI::find_variable_declaration($token);
	if ( not defined $declaration ) {
		$self->{error} = "no declaration";
		return;
	}

	my $scope = $declaration;
	while ( not $scope->isa('PPI::Document') and not $scope->isa('PPI::Structure::Block') ) {
		$scope = $scope->parent;
	}

	my $token_str = $token->content;
	my $varname   = $token->symbol;

	#warn "VARNAME: $varname";

	# TODO: This could be part of PPI somehow?
	# The following string of hacks is simply for finding symbols in quotelikes and regexes
	my $type = substr( $varname, 0, 1 );
	my $brace = $type eq '@' ? '[' : ( $type eq '%' ? '{' : '' );

	my @patterns;
	if ( $type eq '@' or $type eq '%' ) {
		my $accessv = $varname;
		$accessv =~ s/^\Q$type\E/\$/;
		@patterns = (
			quotemeta( _curlify($varname) ), quotemeta($varname),
			quotemeta($accessv) . '(?=' . quotemeta($brace) . ')',
		);
		if ( $type eq '%' ) {
			my $slicev = $varname;
			$slicev =~ s/^\%/\@/;
			push @patterns, quotemeta($slicev) . '(?=' . quotemeta($brace) . ')';
		} elsif ( $type eq '@' ) {
			my $indexv = $varname;
			$indexv =~ s/^\@/\$\#/;
			push @patterns, quotemeta($indexv);
		}
	} else {
		@patterns = ( quotemeta( _curlify($varname) ), quotemeta($varname) . "(?![\[\{])" );
	}
	my %unique;
	my $finder_regexp = '(?:' . join( '|', grep { !$unique{$_}++ } @patterns ) . ')';

	$finder_regexp = qr/$finder_regexp/;    # used to find symbols in quotelikes and regexes
	                                        #warn $finder_regexp;

	my $replacement = substr( $self->{replacement}, 1 );

	$scope->find(
		sub {
			my $node = $_[1];
			if ( $node->isa("PPI::Token::Symbol") ) {
				return 0 unless $node->symbol eq $varname;

				# TODO do this without breaking encapsulation!
				$node->{content} = substr( $node->content(), 0, 1 ) . $replacement;
			}
			if ( $type eq '@' and $node->isa("PPI::Token::ArrayIndex") ) {    # $#foo
				return 0 unless substr( $node->content, 2 ) eq substr( $varname, 1 );

				# TODO do this without breaking encapsulation!
				$node->{content} = '$#' . $replacement;
			} elsif ( $node->isa("PPI::Token") ) {    # the case of potential quotelikes and regexes
				my $str = $node->content;
				if ($str =~ s{($finder_regexp)([\[\{]?)}<
				        if ($1 =~ tr/{//) { substr($1, 0, ($1=~tr/#//)+1) . "{$replacement}$2" }
				        else              { substr($1, 0, ($1=~tr/#//)+1) . "$replacement$2" }
				    >ge
					)
				{

					# TODO do this without breaking encapsulation!
					$node->{content} = $str;
				}
			}
			return 0;
		},
	);

	$self->{token_location} = $token->location;    # for moving the cursor after updating the text
	     # TODO: passing this back and forth is probably hyper-inefficient, but such is life.
	$self->{updated_document_string} = $ppi->serialize;

	return ();
}

sub _curlify {
	my $var = shift;
	if ( $var =~ s/^([\$\@\%])(.+)$/${1}{$2}/ ) {
		return ($var);
	}
	return ();
}

sub finish {
	my $self = shift;
	if ( defined $self->{updated_document_string} ) {

		# GUI update
		# TODO: What if the document changed? Bad luck for now.
		$self->{main_thread_only}->{document}->editor->SetText( $self->{updated_document_string} );
		$self->{main_thread_only}->{document}->ppi_select( $self->{token_location} );
	} else {
		my $text;
		if ( $self->{error} eq 'no token' ) {
			$text = Wx::gettext("Current cursor does not seem to point at a variable");
		} elsif ( $self->{error} eq 'no declaration' ) {
			$text = Wx::gettext("No declaration could be found for the specified (lexical?) variable");
		} else {
			$text = Wx::gettext("Unknown error");
		}
		Wx::MessageBox(
			$text,
			Wx::gettext("Check Canceled"),
			Wx::wxOK,
			Padre->ide->wx->main
		);
	}
	return ();
}

1;

__END__

=head1 SEE ALSO

This class inherits from C<Padre::Task::PPI>.

=head1 AUTHOR

Steffen Mueller C<smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
