package Padre::Task::LexicalReplaceVariable;

use 5.008;
use strict;
use warnings;
use Padre::Task::PPI ();

our $VERSION = '0.94';
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
  $replacer->schedule;

=head1 DESCRIPTION

Given a location in the document (line/column), determines the name of the
variable at this position, finds where the variable was defined,
and B<lexically> replaces all occurrences with another variable.

The replacement can either be provided explicitly by the user (using the
C<replacement> option) or the user may set the C<to_camel_case> or
C<from_camel_case> options. In that case the variable will be converted
to/from camel case. With the latter options, C<ucfirst> will force the
upper-casing of the first letter (as is typical with global variables).

=cut

sub process {
	my $self     = shift;
	my $ppi      = shift or return;
	my $location = $self->{location};

	my %opt;
	$opt{replacement}     = $self->{replacement}     if defined $self->{replacement};
	$opt{to_camel_case}   = $self->{to_camel_case}   if defined $self->{to_camel_case};
	$opt{from_camel_case} = $self->{from_camel_case} if defined $self->{from_camel_case};
	$opt{'ucfirst'}       = $self->{'ucfirst'};
	my $munged = eval {
		require PPIx::EditorTools::RenameVariable;
		PPIx::EditorTools::RenameVariable->new->rename(
			ppi    => $ppi,
			line   => $location->[0],
			column => $location->[1],
			%opt,
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

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
