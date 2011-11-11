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
Padre::Wx::Editor API.

By doing as much preliminary calculations as possible in the background and
passing a Padre::Delta back to the parent, the amount of time spent blocking in
the foreground is kept to an absolute minimum.

=cut

use 5.008;
use strict;
use warnings;

our $VERSION = '0.92';





######################################################################
# Constructor

sub new {
	my $class = shift;
	return bless {
		mode    => shift,
		targets => [@_],
	}, $class;
}

sub mode {
	$_[0]->{mode};
}

sub from_diff {
	my $class   = shift;
	my @targets = ();

	# Build the series of target replacements
	while (@_) {
		my $lines  = 0;
		my $target = {
			start => 0,
			end   => 0,
			text  => '',
		};

		if ( $_[0]->[0] eq '+' ) {

			# The start and end of the target is the beginning of
			# the insertion record.
			my $change = shift;
			my $mode   = $change->[0];
			my $line   = $change->[1];
			my $text   = $change->[2];
			$target->{start} = $line;
			$target->{end}   = $line;
			$target->{text}  = $text . "\n";
			$lines           = 1;

		} else {

			# The change starts with a removal block
			my $change = shift;
			my $mode   = $change->[0];
			my $line   = $change->[1];
			my $text   = $change->[2];
			$target->{start} = $line;
			$target->{end}   = $line + 1;

			# Append any additional removal rows
			while ( @_ and $_[0]->[0] eq '-' ) {
				unless ( $_[0]->[1] == $target->{end} ) {
					last;
				}
				shift;
				$target->{end}++;
			}
		}

		# Append any additional addition rows
		while ( @_ and $_[0]->[0] eq '+' ) {
			unless ( $_[0]->[1] == $target->{end} + $lines ) {
				last;
			}
			$target->{text} .= shift->[2] . "\n";
			$lines++;
		}

		# This completes one entire target replace unit
		push @targets, $target;
	}

	return $class->new( 'line', @targets );
}

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

	# Apply positions based on raw positions
	if ( $mode eq 'position' ) {
		foreach my $target (@$targets) {
			$editor->SetTargetStart( $target->{start} );
			$editor->SetTargetEnd( $target->{end} );
			$editor->BeginUndoAction unless $changed++;
			$editor->ReplaceTarget( $target->{text} );
		}

		# Apply positions based on lines
	} elsif ( $mode eq 'line' ) {

		foreach my $target (@$targets) {
			$editor->SetTargetStart( $editor->PositionFromLine( $target->{start} ) );
			$editor->SetTargetEnd( $editor->PositionFromLine( $target->{end} ) );
			$editor->BeginUndoAction unless $changed++;
			$editor->ReplaceText( $target->{text} );
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
