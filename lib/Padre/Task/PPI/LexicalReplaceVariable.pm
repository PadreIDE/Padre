
package Padre::Task::PPI::LexicalReplaceVariable;
use strict;
use warnings;

our $VERSION = '0.24';

use base 'Padre::Task::PPI';

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
	if (not defined $mto->{document}) {
		require Carp;
		Carp::croak("Missing Padre::Document::Perl object as {document} attribute of the brace-finder task");
	}
	
	if (not defined $self->{replacement}) {
		require Carp;
		Carp::croak("Need a {replacement}!");
	}

	if (not defined $self->{location}) {
		require Carp;
		Carp::croak("Need a {location}!");
	}

	return();
}


sub process_ppi {
	# find bad braces
	my $self = shift;
	my $ppi = shift or return;
	my $location = $self->{location};

	$ppi->flush_locations(); # TODO: PPI bug? This shouldn't be necessary!
	my $token = Padre::PPI::find_token_at_location($ppi, $location);
	if (not $token) {
		$self->{error} = "no token";
		return;
	}

	my $declaration = Padre::PPI::find_variable_declaration($token);
	if (not defined $declaration) {
		$self->{error} = "no declaration";
		return;
	}
	my $scope = $declaration->parent;
	while ( not $scope->isa('Padre::Document') and not $scope->isa('PPI::Structure::Block') ) {
		$scope = $scope->parent;
	}

	my $token_str = $token->content;
	my $varname = $token->canonical;

	# TODO: This could be part of PPI somehow?
	# for finding symbols in quotelikes and regexes
	my %unique;
	my $finder_regexp = '(?:'
	                    . join('|', map {quotemeta($_)} grep {!$unique{$_}++} ($varname, $token_str))
	                    . ')';
	$finder_regexp = qr/$finder_regexp/;

	my $replacement = $self->{replacement};

	$scope->find(
		sub {
			my $node = $_[1];
			if ($node->isa("PPI::Token::Symbol")) {
				return 0 unless $node->canonical eq $varname
				or $node->content eq $token_str; # <--- probably not necessary
				# TODO do this without breaking encapsulation!
				$node->{content} = $replacement;
			}
			elsif ($node->isa("PPI::Token")) { # the case of potential quotelikes and regexes
				my $str = $node->content;
				if ($str =~ s/($finder_regexp)/$replacement/g) {
					# TODO do this without breaking encapsulation!
					$node->{content} = $str;
				}
			}
			return 0;
		},
	);

	$self->{token_location} = $token->location; # for moving the cursor after updating the text
	# TODO: passing this back and forth is probably hyper-inefficient, but such is life.
	$self->{updated_document_string} = $ppi->serialize;

	return();
}


sub finish {
	my $self = shift;
	if (defined $self->{updated_document_string}) {
		# GUI update
		# TODO: What if the document changed? Bad luck for now.
		$self->{main_thread_only}{document}->editor->SetText( $self->{updated_document_string} );
		$self->{main_thread_only}{document}->ppi_select( $self->{token_location} );
	}
	else {
		my $text;
		if ($self->{error} eq 'no token') {
			$text = Wx::gettext("Current cursor does not seem to point at a variable");
		}
		elsif ($self->{error} eq 'no declaration') {
			$text = Wx::gettext("No declaration could be found for the specified (lexical?) variable");
		}
		else {
			$text = Wx::gettext("Unknown error");
		}
		Wx::MessageBox(
			$text,
			Wx::gettext("Check Canceled"),
			Wx::wxOK,
			Padre->ide->wx->main_window
		);
	}
	return();
}


1;

__END__

=head1 SEE ALSO

This class inherits from C<Padre::Task::PPI>.

=head1 AUTHOR

Steffen Mueller C<smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Gabor Szabo.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
