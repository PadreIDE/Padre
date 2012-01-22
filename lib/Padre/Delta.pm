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

our $VERSION = '0.94';





######################################################################
# Constructors

=pod

    # Alter a document by line range, in loose form
    my $delta1 = Padre::Delta->new(
        'line',
        [ 1, 1, 'Content'   ], # Insert a single line
        [ 4, 3, ''          ], # Remove a single line
        [ 6, 9, 'Alternate' ], # Replace three lines with one
    )->tidy;
    
    # Alter a document by character range in tight form
    my $delta2 = Padre::Delta->new(
        'position',
        [ 35, 37, 'fghjkl' ], # Replace two characters with six
        [ 23, 27, ''       ], # Remove four characters
        [ 12, 12, 'abcd'   ], # Insert four characters
    );

The C<new> constructor takes a replacement mode and a list of targets
and returns the delta object, which can then be applied to a C<SCALAR>
reference of L<Padre::Wx::Editor> object.

The first parameter should be the replacement mode. This will be either
C<'line'> for line range deltas as per the F<diff> program, or
C<'position'> for character position range deltas which operate at a
lower level and directly on top of the position system of L<Wx::Scintilla>.

After the replacement mode, the constructor is provided with an arbitrarily
sized list of replacement targets.

Each replacement target should be an C<ARRAY> reference containing three
elements which will be the start of the range to be removed, the end of the
range to be removed, and the text to replace the range with.

The start of the range must always be a lower value than the end of the
range. While providing a high to low range may incidentall work on some
operating systems, on others it can cause L<Wx::Scintilla> to segfault.

Each replacement target will both remove existing content and replace it
with new content. To achieve a simple insert, both range positions should
be set to the same value at the position you wish to insert at. To achieve
a simple deletion the replacement string should be set to the null string.

The ordering of the replacement target is critically important. When the
changes applied they will always be made naively and in the same order
as supplied to the constructor.

Because a change early in the document will alter the positions of all
content after it, you should be very careful to ensure that your change
makes sense if applied in the supplied order.

If the positions of your replacement targets are not inherently
precalculated to adjust for content changes, you should supply your
changes from the bottom of the document upwards.

Returns the new L<Padre::Delta> object.

=cut

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

=head2 tidy

    Padre::Delta->new( line => @lines )->tidy->to_editor($editor);

The C<tidy> method is provided as a convenience for situations where the
quality of the replacement targets passed to the constructor is imperfect.

To ensure that changes are applied quickly and editor objects are locked for
the shortest time possible, the replacement targets in the delta are
considered to have an inherent order and are always applied naively.

For situations where the replacement targets do B<not> have an inherent
order, applying them in the order provided will result in a corrupted
transform.

Calling tidy on a delta object will correct ranges that are not provided
in low to high order and sort them so changes are applied from the bottom
of the document upwards to avoid document corruption.

Returns the same L<Padre::Delta> object as a convenience so that the tidy
method can be used in changed calls as demonstrated above.

=cut

sub tidy {
	my $self    = shift;
	my $targets = $self->{targets};
	                               
	# Correct out-of-order ranges
	foreach my $t ( @$targets ) {
		next unless $t->[0] > $t->[1];
		@$t = ( $t->[1], $t->[0], $t->[2] );
	}

	# Sort from bottom to top
	@$targets = sort { $b->[0] <=> $a->[0] } @$targets;

	return $self;
}

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
