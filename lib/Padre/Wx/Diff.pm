package Padre::Wx::Diff;

use 5.008;
use strict;
use warnings;
use Scalar::Util            ();
use Params::Util            ();
use Padre::Constant         ();
use Padre::Role::Task       ();
use Padre::Wx               ();
use Padre::Util             ();
use Padre::Wx::Dialog::Diff ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
};





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $main  = shift;

	my $self = bless {@_}, $class;
	$self->{main} = $main;

	$self->{diffs} = {};

	return $self;
}





######################################################################
# Padre::Role::Task Methods

sub task_finish {
	TRACE( $_[1] ) if DEBUG;
	my $self   = shift;
	my $task   = shift;
	my $chunks = Params::Util::_ARRAY0( $task->{data} ) or return;
	my $main   = $self->{main};
	my $editor = $main->current->editor or return;
	my $lock   = $editor->lock_update;

	# Clear any old content
	$self->clear;

	my $delta = 0;
	$self->{diffs} = {};
	for my $chunk ( @$chunks ) {
		my $marker_line   = undef;
		my $lines_deleted = 0;
		my $lines_added   = 0;
		for my $diff ( @$chunk ) {
			my ( $type, $line, $text ) = @$diff;
			TRACE("$type, $line, $text") if DEBUG;

			unless ($marker_line) {
				$marker_line = $line + $delta;

				$self->{diffs}->{$marker_line} = {
					message  => undef,
					type     => undef,
					old_text => undef,
					new_text => undef,
				};
			}

			my $diff = $self->{diffs}->{$marker_line};

			if ( $type eq '-' ) {
				$lines_deleted++;
				$diff->{old_text} .= $text;
			} else {
				$lines_added++;
				$diff->{new_text} .= $text;
			}
		}

		my $description;
		my $diff = $self->{diffs}->{$marker_line};
		my $type;
		if ( $lines_deleted > 0 and $lines_added > 0 ) {

			# Line(s) changed
			$description =
				$lines_deleted > 1
				? sprintf( Wx::gettext('%d lines changed'), $lines_deleted )
				: sprintf( Wx::gettext('%d line changed'),  $lines_deleted );
			$editor->MarkerDelete( $marker_line, $_ ) for ( Padre::Constant::MARKER_ADDED, Padre::Constant::MARKER_DELETED );
			$editor->MarkerAdd( $marker_line, Padre::Constant::MARKER_CHANGED );
			$type = 'C';

		} elsif ( $lines_added > 0 ) {

			# Line(s) added
			$description =
				$lines_added > 1
				? sprintf( Wx::gettext('%d lines added'), $lines_added )
				: sprintf( Wx::gettext('%d line added'),  $lines_added );
			$editor->MarkerDelete( $marker_line, $_ ) for ( Padre::Constant::MARKER_CHANGED, Padre::Constant::MARKER_DELETED );
			$editor->MarkerAdd( $marker_line, Padre::Constant::MARKER_ADDED );
			$type = 'A';
		} elsif ( $lines_deleted > 0 ) {

			# Line(s) deleted
			$description =
				$lines_deleted > 1
				? sprintf( Wx::gettext('%d lines deleted'), $lines_deleted )
				: sprintf( Wx::gettext('%d line deleted'),  $lines_deleted );
			$editor->MarkerDelete( $marker_line, $_ ) for ( Padre::Constant::MARKER_ADDED, Padre::Constant::MARKER_CHANGED );
			$editor->MarkerAdd( $marker_line, Padre::Constant::MARKER_DELETED );
			$type = 'D';

		} else {

			# TODO No change... what to do there... ignore? :)
			$description = 'no change!';
			$type        = 'N';
		}

		# Record lines added/deleted
		$diff->{lines_added}   = $lines_added;
		$diff->{lines_deleted} = $lines_deleted;
		$diff->{type}          = $type;
		$diff->{message}       = $description;

		# Update the offset
		$delta = $delta + $lines_added - $lines_deleted;

		TRACE("$description at line #$marker_line") if DEBUG;
	}

	$editor->SetMarginSensitive( 1, 1 );
	my $myself = $self;
	Wx::Event::EVT_STC_MARGINCLICK(
		$editor, $editor,
		sub {
			my $self  = shift;
			my $event = shift;

			if ( $event->GetMargin == 1 ) {
				$myself->show_diff_box( $editor->LineFromPosition( $event->GetPosition ), $editor );
			}

			# Keep processing
			$event->Skip(1);
		}
	);

	return 1;
}





######################################################################
# General Methods

sub clear {
	my $self    = shift;
	my $current = $self->{main}->current or return;
	my $editor  = $current->editor       or return;
	my $lock    = $editor->lock_update;

	$editor->MarkerDeleteAll(Padre::Constant::MARKER_ADDED);
	$editor->MarkerDeleteAll(Padre::Constant::MARKER_CHANGED);
	$editor->MarkerDeleteAll(Padre::Constant::MARKER_DELETED);

	$self->{dialog}->Hide if $self->{dialog};
}

sub refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;

	# Cancel any existing diff task
	$self->task_reset;

	# Hide the widgets when no files are open
	unless ($document) {
		$self->clear;
		return;
	}

	# Shortcut if there is nothing to search for
	if ( $document->is_unused ) {
		return;
	}

	# Trigger the task to fetch the refresh data
	$self->task_request(
		task     => 'Padre::Task::Diff',
		document => $document,
	);
}

# Generic method to select next or previous difference
sub _select_next_prev_difference {
	my $self             = shift;
	my $select_next_diff = shift;
	my $current          = $self->{main}->current or return;
	my $editor           = $current->editor or return;

	# Sort lines in ascending order
	my @lines = sort { $a <=> $b } keys %{ $self->{diffs} };

	# Lines in descending order if select previous diff is enabled
	@lines = reverse @lines unless $select_next_diff;

	my $current_line   = $editor->LineFromPosition( $editor->GetCurrentPos );
	my $line_to_select = undef;
	for my $line (@lines) {
		unless ( defined $line_to_select ) {
			$line_to_select = $line;
		}
		if ($select_next_diff) {

			# Next difference
			if ( $line > $current_line ) {
				$line_to_select = $line;
				last;
			}
		} else {

			# Previous difference
			if ( $line < $current_line ) {
				$line_to_select = $line;
				last;
			}
		}
	}
	if ( defined $line_to_select ) {
		# Select the line in the editor and show the diff box
		$editor->goto_line_centerize($line_to_select);
		$self->show_diff_box( $line_to_select, $editor );
	} else {
		$self->{main}->error( Wx::gettext('No changes found') );
	}
}

# Selects the next difference in the editor
sub select_next_difference {
	$_[0]->_select_next_prev_difference(1);
}

# Selects the previous difference in the editor
sub select_previous_difference {
	$_[0]->_select_next_prev_difference(0);
}

# Shows the difference dialog box for the provided line in the editor provided
sub show_diff_box {
	my $self   = shift;
	my $line   = shift;
	my $editor = shift;
	my $diff   = $self->{diffs}->{$line} or return;

	unless ( defined $self->{dialog} ) {
		$self->{dialog} = Padre::Wx::Dialog::Diff->new( $self->{main} );
	}
	$self->{dialog}->show(
		$editor, $line, $diff,
		$editor->PointFromPosition( $editor->PositionFromLine( $line + 1 ) )
	);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
