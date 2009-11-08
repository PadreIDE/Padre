package Padre::Task::PPI::LexicalReplaceVariable;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.50';

use base 'Padre::Task::PPI';
use Padre::Wx ();
use PPIx::EditorTools::RenameVariable;

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

	my $munged = eval {
		PPIx::EditorTools::RenameVariable->new->rename(
			ppi         => $ppi,
			line        => $location->[0],
			column      => $location->[1],
			replacement => $self->{replacement},
		);
	};
	if ($@) {
		$self->{error} = $@;
		return;
	}

	# for moving the cursor after updating the text
	$self->{token_location} = $munged->element->location;

	# TODO: passing this back and forth is probably hyper-inefficient, but such is life.
	$self->{updated_document_string} = $munged->code;

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
		if ( $self->{error} =~ /no token/ ) {
			$text = Wx::gettext("Current cursor does not seem to point at a variable");
		} elsif ( $self->{error} =~ /no declaration/ ) {
			$text = Wx::gettext("No declaration could be found for the specified (lexical?) variable");
		} else {
			$text = Wx::gettext("Unknown error");
		}
		Wx::MessageBox(
			$text,    Wx::gettext("Replace Operation Canceled"),
			Wx::wxOK, Padre->ide->wx->main
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
