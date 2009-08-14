package Padre::Task::PPI::FindUnmatchedBrace;
use strict;
use warnings;

our $VERSION = '0.43';

use base 'Padre::Task::PPI';
use Padre::Wx();
use PPIx::EditorTools::FindUnmatchedBrace;

=pod

=head1 NAME

Padre::Task::PPI::FindUnmatchedBrace - PPI-based unmatched-brace-finder

=head1 SYNOPSIS

  my $bracefinder = Padre::Task::PPI::FindUnmatchedBrace->new(
          document => $document_obj,
  );
  # pass "text => 'foo'" if you want to set the code manually
  # otherwise, the current document will be used
  
  $bracefinder->schedule();

=head1 DESCRIPTION

Finds the location of unmatched braces in a C<Padre::Document::Perl>.
If there is no unmatched brace, a message box tells the user about
that glorious fact. If there is one, the cursor will jump to it.

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
	return ();
}

sub process_ppi {

	# find bad braces
	my $self = shift;
	my $ppi = shift or return;

	my $brace = eval { PPIx::EditorTools::FindUnmatchedBrace->new->find( ppi => $ppi ); };
	if ($@) {
		$self->{error} = $@;
		return;
	}
	if ( defined($brace) ) { # An undef brace throws a die here. undef = no error found.
		$self->{bad_element} = $brace->element->location; # remember for gui update
	}

	return ();
}

sub finish {
	my $self = shift;
	if ( defined $self->{bad_element} ) {

		# GUI update
		$self->{main_thread_only}->{document}->ppi_select( $self->{bad_element} );
	} else {
		Wx::MessageBox(
			Wx::gettext("All braces appear to be matched"),
			Wx::gettext("Check Complete"),
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
