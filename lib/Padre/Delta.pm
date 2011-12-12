package Padre::Delta;

=pod

=head1 NAME

Padre::Delta - A very simple diff object that can be applied to editors fast

=head1 DESCRIPTION

As a refactoring IDE many different modules and tools may wish to calculate
changes to a document in the background and then apply the changes in the
foreground.

B<Padre::Delta> objects provide a mechanism for defining change to an editor,
with the representation stored in a way that is extremely well aligned with the
L<Padre::Wx::Editor> and L<Wx::Scintilla> APIs.

By doing as much preliminary calculations as possible in the background and
passing a Padre::Delta object back to the parent, the amount of time spent
blocking in the foreground is kept to an absolute minimum.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;

our $VERSION = '0.93';





######################################################################
# Constructor

sub new {
	my $class = shift;
	return bless {
		mode    => shift,
		targets => [ @_ ],
	}, $class;
}

=pod

=head2 mode

The C<mode> accessor indicates if the replacement will be done using line
numbers or character positions.

Returns C<'line'> or C<'position'>.

=cut

sub mode {
	$_[0]->{mode};
}

=pod

=head2 null

The C<null> method returns true if the delta contains zero changes to the
document and thus has no effect, or false if the delta contains any changes
to the document.

The ability to create null deltas allows refactoring to indicate a successful
transform resulting in no changes to the current document, as opposed to some
other response indicating a failure to apply the transform or similar response.

=cut

sub null {
	! scalar @{ $_[0]->{targets} };
}

=pod

=head2 from_diff

  my $delta = Padre::Delta->from_diff(
      Algorithm::Diff::diff( \@from => \@to )
  );

The C<from_diff> method takes a list of hunk structures as returned by the
L<Algorithm::Diff> function C<diff> and creates a new delta that will apply
that diff to a document.

Returns a new L<Padre::Delta> object.

=cut

sub from_diff {
	my $class   = shift;
	my @targets = ();

	# Build the series of target replacements
	my $delta = 0;
	while ( @_ ) {
		my $hunk = shift;
		foreach my $change ( @$hunk ) {
			my $operation = $change->[0];
			my $position  = $change->[1];
			my $text      = $change->[2] . "\n";
			my $previous  = $targets[-1];

			if ( $operation eq '-' ) {
				my $start = $position + $delta--;
				if ( $previous and $previous->{end} == $start ) {
					$previous->{end}++;
					next;
				}
				push @targets, {
					start => $start,
					end   => $start + 1,
					text  => '',
				};
				next;
			}

			if ( $operation eq '+' ) {
				if ( $previous and $previous->{end} == $position ) {
					$previous->{text} .= $text;
				} else {
					push @targets, {
						start => $position,
						end   => $position,
						text  => $text,
					};
				}
				$delta++;
				next;
			}

			die "Unknown operation: '$operation'";
		}
	}

	return $class->new( 'line', @targets );
}

=pod

=head2 from_scalars

  my $delta = Padre::Delta->from_scalars( \$from => \$to );

The C<from_scalars> method takes a pair of documents "from" and "to" and creates
a L<Padre::Delta> object that when applied to document "from" will convert it
into document "to".

The documents are provided as SCALAR references to avoid the need for
superfluous copies of what may be relatively large strings.

Returns a new L<Padre::Delta> object.

=cut

sub from_scalars {
	my $self = shift;

	# Split the scalar refs into lines
	my @from = split /\n/, ${ shift() };
	my @to   = split /\n/, ${ shift() };

	# Diff the two line sets
	require Algorithm::Diff;
	my @diff = Algorithm::Diff::diff( \@from => \@to );

	# Hand off to the diff-based constructor
	return $self->from_diff(@diff);
}





######################################################################
# Main Methods

sub to_editor {
	my $self    = shift;
	my $editor  = shift;
	my $mode    = $self->{mode};
	my $targets = $self->{targets};
	my $changed = 0;

	if ( $mode eq 'position' ) {
		# Apply positions based on raw positions
		foreach my $target (@$targets) {
			$editor->SetTargetStart( $target->{start} );
			$editor->SetTargetEnd( $target->{end} );
			$editor->BeginUndoAction unless $changed++;
			$editor->ReplaceTarget( $target->{text} );
		}

	} elsif ( $mode eq 'line' ) {
		# Apply positions based on lines
		foreach my $target (@$targets) {
			$editor->SetTargetStart( $editor->PositionFromLine( $target->{start} ) );
			$editor->SetTargetEnd( $editor->PositionFromLine( $target->{end} ) );
			$editor->BeginUndoAction unless $changed++;
			$editor->ReplaceTarget( $target->{text} );
		}

	} else {
		die "Unexpected delta mode '$mode'";
	}

	$editor->EndUndoAction if $changed;

	return;
}

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
