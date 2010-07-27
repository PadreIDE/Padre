package Padre::Task::LexicalReplaceVariable;

use 5.008;
use strict;
use warnings;
use Padre::Task::PPI ();

our $VERSION = '0.68';
our @ISA     = 'Padre::Task::PPI';

=pod

=head1 NAME

Padre::Task::LexicalReplaceVariable - Lexically variable replace using L<PPI>

=head1 SYNOPSIS

  my $replacer = Padre::Task::LexicalReplaceVariable->new(
          document    => $document_obj,
          location    => [ $line, $column ], # the position of *any* occurrence of the variable
          replacement => '$foo',
  );
  $replacer->schedule();

=head1 DESCRIPTION

Given a location in the document (line/column), determines the name of the
variable at this position, finds where the variable was defined,
and B<lexically> replaces all occurrences with another variable.

=cut

sub process {
	my $self     = shift;
	my $ppi      = shift or return;
	my $location = $self->{location};

	my $munged = eval {
		require PPIx::EditorTools::RenameVariable;
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

	# Save the results
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

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
