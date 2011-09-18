package Padre::Wx::Diff;

use 5.008;
use strict;
use warnings;
use Scalar::Util      ();
use Params::Util      ();
use Padre::Role::Task ();
use Padre::Wx         ();
use Padre::Util       ();
use Padre::Logger;

our $VERSION = '0.91';
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

	return $self;
}





#####################################################################
# Event Handlers


######################################################################
# Padre::Role::Task Methods

sub task_finish {
	TRACE( $_[1] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $data = Params::Util::_ARRAY0( $task->{data} ) or return;
	my $lock = $self->{main}->lock('UPDATE');

	my $editor = $self->{main}->current->editor;

	# Clear any old content
	$self->clear;

	my @diffs = @{$data};
	$self->{diff_text} = {};
	my $deleted_style  = sprintf( '%c', Padre::Constant::PADRE_ERROR() );
	my $addition_style = sprintf( '%c', Padre::Constant::PADRE_WARNING() );

	for my $diff_chunk (@diffs) {
		my $marker_line   = undef;
		my $lines_deleted = 0;
		my $lines_added   = 0;
		for my $diff ( @{$diff_chunk} ) {
			my ( $type, $line, $text ) = @$diff;
			TRACE("$type, $line, $text") if DEBUG;

			unless ($marker_line) {
				$marker_line = $line;

				$self->{diff_text}->{$marker_line} = {
					message => '',
					style   => '',
				};
			}

			$self->{diff_text}->{$marker_line}->{message} .= $text;

			if ( ( $type eq '-' ) ) {
				$lines_deleted++;
				$self->{diff_text}->{$marker_line}->{style} .= ( $deleted_style x length($text) );
			} else {
				$lines_added++;
				$self->{diff_text}->{$marker_line}->{style} .= ( $addition_style x length($text) );
			}
		}

		my $description;
		if ( $lines_deleted > 0 and $lines_added > 0 ) {

			# Line(s) changed
			$description =
				$lines_deleted > 1
				? sprintf( Wx::gettext('%d lines changed'), $lines_deleted )
				: sprintf( Wx::gettext('%d line changed'),  $lines_deleted );
			$editor->MarkerDelete( $marker_line, Padre::Wx::MarkAddition );
			$editor->MarkerDelete( $marker_line, Padre::Wx::MarkDeletion );
			$editor->MarkerAdd( $marker_line, Padre::Wx::MarkChange );
		} elsif ( $lines_added > 0 ) {

			# Line(s) added
			$description =
				$lines_added > 1
				? sprintf( Wx::gettext('%d lines added'), $lines_added )
				: sprintf( Wx::gettext('%d line added'),  $lines_added );
			$editor->MarkerDelete( $marker_line, Padre::Wx::MarkChange );
			$editor->MarkerDelete( $marker_line, Padre::Wx::MarkDeletion );
			$editor->MarkerAdd( $marker_line, Padre::Wx::MarkAddition );
		} elsif ( $lines_deleted > 0 ) {

			# Line(s) deleted
			$description =
				$lines_deleted > 1
				? sprintf( Wx::gettext('%d lines deleted'), $lines_deleted )
				: sprintf( Wx::gettext('%d line deleted'),  $lines_deleted );
			$editor->MarkerDelete( $marker_line, Padre::Wx::MarkAddition );
			$editor->MarkerDelete( $marker_line, Padre::Wx::MarkChange );
			$editor->MarkerAdd( $marker_line, Padre::Wx::MarkDeletion );

		} else {

			# TODO No change... what to do there... ignore? :)
			$description = 'no change!';
		}

		$description .= "\n";
		$self->{diff_text}->{$marker_line}->{message} = $description . $self->{diff_text}->{$marker_line}->{message};
		$self->{diff_text}->{$marker_line}->{style} =
			( "\001" x length($description) ) . $self->{diff_text}->{$marker_line}->{style};

		TRACE("$description at line #$marker_line") if DEBUG;
	}

	$editor->SetMarginSensitive( 1, 1 );
	my $diff_text = $self->{diff_text};
	Wx::Event::EVT_STC_MARGINCLICK(
		$editor, $editor,
		sub {
			my $self  = shift;
			my $event = shift;

			if ( $event->GetMargin == 1 ) {
				my $position = $event->GetPosition;
				my $line     = $editor->LineFromPosition($position);
				if ( $diff_text->{$line} ) {
					$editor->AnnotationClearAll;
					$editor->AnnotationSetText( $line, $diff_text->{$line}->{message} );
					$editor->AnnotationSetStyles( $line, $diff_text->{$line}->{style} );
					$editor->AnnotationSetVisible(2); #TODO use Wx::wxSTC_ANNOTATION_BOXED once it is there
				}
			}
		}
	);

	return 1;
}

######################################################################
# General Methods

sub clear {
	my $self    = shift;
	my $current = $self->{main}->current or return;
	my $editor  = $current->editor or return;

	$editor->MarkerDeleteAll(Padre::Wx::MarkAddition);
	$editor->MarkerDeleteAll(Padre::Wx::MarkChange);
	$editor->MarkerDeleteAll(Padre::Wx::MarkDeletion);
}

sub refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;
	my $lock     = $self->{main}->lock('UPDATE');

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

# Selects the next difference in the editor
sub select_next_difference {
	my $self = shift;

	# TODO  implement select_next_difference
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
