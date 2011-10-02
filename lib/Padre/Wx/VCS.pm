package Padre::Wx::VCS;

use 5.008;
use strict;
use warnings;
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx             ();
use Padre::Wx::FBP::VCS   ();
use Padre::Logger;

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::FBP::VCS
};

# Constructor
sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;
	my $self  = $class->SUPER::new($panel);

	# Set the bitmap button icons
	$self->{refresh}->SetBitmapLabel( Padre::Wx::Icon::find('actions/view-refresh') );

	my @titles = qw(Revision Author Status File);
	foreach my $i ( 0 .. $#titles ) {
		$self->{list}->InsertColumn( $i, Wx::gettext( $titles[$i] ) );
		$self->{list}->SetColumnWidth( $i, Wx::LIST_AUTOSIZE );
	}

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	$_[0]->main->show_vcs(0);
}

sub view_start {
}

sub view_stop {
	my $self = shift;

	# Clear out any state and tasks
	$self->task_reset;
	$self->clear;

	return;
}

#####################################################################
# Event Handlers

sub on_refresh_click {
	$_[0]->main->vcs->refresh( $_[0]->current );
}

#####################################################################
# General Methods

sub gettext_label {
	Wx::gettext('Version Control');
}

# Clear everything...
sub clear {
	my $self = shift;
	
	$self->{list}->DeleteAllItems;

	return;
}

# Nothing to implement here
sub relocale {
	return;
}

sub refresh {
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;

	# Abort any in-flight checks
	$self->task_reset;

	# Hide the widgets when no files are open
	unless ($document) {
		$self->clear;
		return;
	}

	# Shortcut if there is nothing in the document to compile
	if ( $document->is_unused ) {
		return;
	}

	# Fire the background task discarding old results
	$self->task_request(
		task     => 'Padre::Task::VCS',
		document => $document,
	);

	return 1;
}

sub task_finish {
	my $self = shift;
	my $task = shift;
	$self->{model} = $task->{model};

	# TODO validate model

	$self->render;
}

sub render {
	my $self = shift;
	my $model = $self->{model} || {};

	# Flush old results
	$self->clear;

	my $index = 0;
	my $list  = $self->{list};
	for my $rec (@$model) {
		my $status = $rec->{status};
		if ( $status ne ' ' ) {
			if ( $status eq 'M' ) {
				$status = 'Modified';
			} elsif ( $status eq 'A' ) {
				$status = 'Added';
			} elsif ( $status eq 'D' ) {
				$status = 'Deleted';
			} elsif ( $status eq 'M' ) {
				$status = 'Modified';
			}

			# Add a version control entry
			$list->InsertStringItem( $index, $rec->{current} );
			$list->SetItem( $index, 1, $rec->{author} );
			$list->SetItem( $index, 2, $status );
			$list->SetItem( $index, 3, $rec->{file} );

			$index++;
		}
	}

	$self->_resize_columns;

	return 1;
}

# Private method to resize list columns
sub _resize_columns {
	my $self = shift;

	# Resize all columns but the last to their biggest item width
	my $list = $self->{list};
	for ( 0 .. $list->GetColumnCount - 1 ) {
		$list->SetColumnWidth( $_, Wx::LIST_AUTOSIZE );
	}

	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
