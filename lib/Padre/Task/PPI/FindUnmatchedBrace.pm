
package Padre::Task::PPI::FindUnmatchedBrace;
use strict;
use warnings;

our $VERSION = '0.24';

use base 'Padre::Task::PPI';

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
	if (not defined $mto->{document}) {
		require Carp;
		Carp::croak("Missing Padre::Document::Perl object as {document} attribute of the brace-finder task");
	}
	return();
}

sub process_ppi {
	# find bad braces
	my $self = shift;
	my $ppi = shift or return;
	require Padre::PPI;
	my $where = $ppi->find( \&Padre::PPI::find_unmatched_brace );
	if ( $where ) {
		@$where = sort {
			Padre::PPI::element_depth($b) <=> Padre::PPI::element_depth($a)
			or
			$a->location->[0] <=> $b->location->[0]
			or
			$a->location->[1] <=> $b->location->[1]
		} @$where;
		$self->{bad_element} = $where->[0]->location; # remember for gui update
	}
	return();
}

sub finish {
	my $self = shift;
	if (defined $self->{bad_element}) {
		# GUI update
		$self->{main_thread_only}{document}->ppi_select( $self->{bad_element} );
	}
	else {
		Wx::MessageBox(
			Wx::gettext("All braces appear to be matched"),
			Wx::gettext("Check Complete"),
			Wx::wxOK(),
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
