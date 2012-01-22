package Padre::Task::IntroduceTemporaryVariable;

use 5.008;
use strict;
use warnings;
use Padre::Task::PPI ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task::PPI';

=pod

=head1 NAME

Padre::Task::IntroduceTemporaryVariable - Introduces a temporary variable using L<PPI>

=head1 SYNOPSIS

  my $tempvarmaker = Padre::Task::IntroduceTemporaryVariable->new(
          document       => $document_obj,
          start_location => [$line, $column], # or just character position
          end_location   => [$line, $column], # or ppi-style location
          varname        => '$foo',
  );

  $tempvarmaker->schedule;

=head1 DESCRIPTION

Given a region of code within a statement, replaces that code with a temporary variable.
Declares and initializes the temporary variable right above the statement that included the selected
expression.

Usually, you simply set C<start_position> to what C<< $editor->GetSelectionStart >> returns
and C<end_position> to C<< $editor->GetSelectionEnd - 1 >>.

=cut

sub process {
	my $self = shift;
	my $ppi = shift or return;

	# Transform the document
	my $munged = eval {
		require PPIx::EditorTools::IntroduceTemporaryVariable;
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

	# TO DO: passing this back and forth is probably hyper-inefficient, but such is life.
	$self->{munged}   = $munged->code;
	$self->{location} = $munged->element->location;

	return;
}

1;

__END__

=head1 SEE ALSO

This class inherits from C<Padre::Task::PPI>.

=head1 AUTHOR

Steffen Mueller C<smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
