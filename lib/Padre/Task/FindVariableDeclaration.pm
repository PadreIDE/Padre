package Padre::Task::FindVariableDeclaration;

use 5.008;
use strict;
use warnings;
use Padre::Task::PPI ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task::PPI';

=pod

=head1 NAME

Padre::Task::FindVariableDeclaration - Finds where a variable was declared using L<PPI>

=head1 SYNOPSIS

  # Find declaration of variable at cursor
  my $task = Padre::Task::FindVariableDeclaration->new(
          document => $document_obj,
          location => [ $line, $column ], # ppi-style location is okay, too
  );

  $task->schedule;

=head1 DESCRIPTION

Finds out where a variable has been declared.
If unsuccessful, a message box tells the user about
that glorious fact. If a declaration is found, the cursor will jump to it.

=cut

sub process {
	my $self     = shift;
	my $ppi      = shift or return;
	my $location = $self->{location};
	my $result   = eval {
		require PPIx::EditorTools::FindVariableDeclaration;
		PPIx::EditorTools::FindVariableDeclaration->new->find(
			ppi    => $ppi,
			line   => $location->[0],
			column => $location->[1]
		);
	};
	if ($@) {
		$self->{error} = $@;
		return;
	}

	# If we found it, save the location
	if ( defined $result ) {
		$self->{location} = $result->element->location;
	}

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
