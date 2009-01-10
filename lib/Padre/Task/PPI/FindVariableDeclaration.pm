package Padre::Task::PPI::FindVariableDeclaration;

use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.25';

use base 'Padre::Task::PPI';

=pod

=head1 NAME

Padre::Task::PPI::FindVariableDeclaration - Finds where a variable was declared using PPI

=head1 SYNOPSIS

  # finds declaration of varibable at cursor
  my $declfinder = Padre::Task::PPI::FindVariableDeclaration->new(
          document => $document_obj,
          location => [$line, $column], # ppi-style location is okay, too
  );
  
  $declfinder->schedule();

=head1 DESCRIPTION

Finds out where a variable has been declared.
If unsuccessful, a message box tells the user about
that glorious fact. If a declaration is found, the cursor will jump to it.

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
	$self->{declaration_location} = $declaration->location;
	return();
}

sub finish {
	my $self = shift;
	if (defined $self->{declaration_location}) {
		# GUI update
		$self->{main_thread_only}{document}->ppi_select( $self->{declaration_location} );
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
			Padre->ide->wx->main
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
