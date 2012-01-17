package Padre::Delta;

=pod

=head1 NAME

Padre::Delta - A very simple diff object that can be applied to editors fast

=head1 SYNOPSIS

  my $editor = Padre::Current->editor;
  my $from   = $editor->GetText;
  my $to     = transform_function($from);
  Padre::Delta->from_scalars( \$from => \$to )->to_editor($editor);

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
			my $previous  = $targets[-1];
			my $operation = $change->[0];
			my $pos       = $change->[1];

			if ( $operation eq '-' ) {
				my $start = $pos + $delta--;
				if ( $previous and $previous->[1] == $pos ) {
					$previous->[1]++;
					next;
				}
				push @targets, [ $start, $start + 1, '' ];
				next;
			}

			if ( $operation eq '+' ) {
				my $text = $change->[2] . "\n";
				if ( $previous and $previous->[1] == $pos ) {
					$previous->[2] .= $text;
				} else {
					push @targets, [ $pos, $pos, $text ];
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

=pod

=head2 to_editor

  my $changes = $delta->to_editor($editor);

The C<to_editor> method applies the changes in a delta object to a
L<Padre::Wx::Editor> instance.

The changes are applied in the most simple and direct manner possible,
wrapped in a single Undo action for easy of reversion, and in an update
locker for speed.

Return the number of changes made to the text contained in the editor,
which may be zero in the case of a null delta.

=cut

sub to_editor {
	my $self = shift;

	# Shortcut if nothing to do
	return 0 if $self->null;

	# Prepare to apply to the editor
	my $editor  = shift;
	my $mode    = $self->{mode};
	my $targets = $self->{targets};
	my $lock    = $editor->lock_update;

	if ( $mode eq 'line' ) {
		# Apply positions based on lines
		$editor->BeginUndoAction;
		foreach my $target (@$targets) {
			$editor->SetTargetStart( $editor->PositionFromLine( $target->[0] ) );
			$editor->SetTargetEnd( $editor->PositionFromLine( $target->[1] ) );
			$editor->ReplaceTarget( $target->[2] );
		}
		$editor->EndUndoAction;

	} elsif ( $mode eq 'position' ) {
		# Apply positions based on raw character positions
		$editor->BeginUndoAction;
		foreach my $target (@$targets) {
			$editor->SetTargetStart( $target->[0] );
			$editor->SetTargetEnd( $target->[1] );
			$editor->ReplaceTarget( $target->[2] );
		}
		$editor->EndUndoAction;
	}

	return scalar @$targets;
}

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
