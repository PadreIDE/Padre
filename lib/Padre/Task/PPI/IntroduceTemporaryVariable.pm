package Padre::Task::PPI::IntroduceTemporaryVariable;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.45';

use base 'Padre::Task::PPI';
use PPIx::EditorTools::IntroduceTemporaryVariable;

=pod

=head1 NAME

Padre::Task::PPI::IntroduceTemporaryVariable - Introduces a temporary variable using PPI

=head1 SYNOPSIS

  my $tempvarmaker = Padre::Task::PPI::IntroduceTemporaryVariable->new(
          document       => $document_obj,
          start_location => [$line, $column], # or just character position
          end_location   => [$line, $column], # or ppi-style location
          varname        => '$foo',
  );
  
  $tempvarmaker->schedule();

=head1 DESCRIPTION

Given a region of code within a statement, replaces that code with a temporary variable.
Declares and initializes the temporary variable right above the statement that included the selected
expression.

Usually, you simply set C<start_position> to what C<<$editor->GetSelectionStart()>> returns
and C<end_position> to C<<$editor->GetSelectionEnd() - 1>>.

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
		Carp::croak("Missing Padre::Document::Perl object as {document} attribute of the temporary-variable task");
	}

	foreach my $key (qw(start_location end_location)) {
		if ( not defined $self->{$key} ) {
			require Carp;
			Carp::croak("Need a {$key}!");
		} elsif ( not ref( $self->{$key} ) ) {
			my $doc = $mto->{document};
			$self->{$key} = $doc->character_position_to_ppi_location( $self->{$key} );
		}
	}

	return ();
}

sub process_ppi {
	my $self     = shift;
	my $ppi      = shift or return;
	my $location = $self->{start_location};

	my $munged = eval {
		PPIx::EditorTools::IntroduceTemporaryVariable->new->introduce(
			ppi            => $ppi,
			start_location => $self->{start_location},
			end_location   => $self->{end_location},
			varname        => $self->{varname},
		);
	};
	if ($@) {
		$self->{error} = $@;
		return;
	}

	# TODO: passing this back and forth is probably hyper-inefficient, but such is life.
	$self->{updated_document_string} = $munged->code;
	$self->{location}                = $munged->element->location;
	return ();
}

sub finish {
	my $self = shift;
	if ( defined $self->{updated_document_string} ) {

		# GUI update
		# TODO: What if the document changed? Bad luck for now.
		$self->{main_thread_only}->{document}->editor->SetText( $self->{updated_document_string} );
		$self->{main_thread_only}->{document}->ppi_select( $self->{location} );
	} else {
		my $text;
		if ( $self->{error} =~ /no token/ ) {
			$text = Wx::gettext("First character of selection does not seem to point at a token.");
		} elsif ( $self->{error} =~ /no statement/ ) {
			$text = Wx::gettext("Selection not part of a Perl statement?");
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
