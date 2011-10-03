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

	# Setup columns
	my @column_headers = (
		Wx::gettext('Revision'),
		Wx::gettext('Author'),
		Wx::gettext('Status'),
		Wx::gettext('Path'),
	);
	my $index = 0;
	for my $column_header (@column_headers) {
		$self->{list}->InsertColumn( $index++, $column_header );
	}

	# Tidy the list
	Padre::Util::tidy_list( $self->{list} );

	# TODO get these from configuration parameters?
	$self->{show_normal}->SetValue(0);
	$self->{show_unversioned}->SetValue(1);
	$self->{show_ignored}->SetValue(0);

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

	# Only subversion is supported at the moment
	my $vcs = $document->project->vcs;
	if ( $vcs ne Padre::Constant::SUBVERSION ) {
		$self->{status}
			->SetLabel( sprintf( Wx::gettext('%s version control project support is not currently supported'), $vcs ) );
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
	$self->{model} = Params::Util::_ARRAY0( $task->{model} ) or return;

	$self->render;
}

sub render {
	my $self = shift;

	# Flush old results
	$self->clear;

	# Define SVN status
	my %SVN_STATUS = (
		' ' => { name => Wx::gettext('Normal') },
		'A' => { name => Wx::gettext('Added') },
		'D' => { name => Wx::gettext('Deleted') },
		'M' => { name => Wx::gettext('Modified') },
		'C' => { name => Wx::gettext('Conflicted') },
		'I' => { name => Wx::gettext('Ignored') },
		'?' => { name => Wx::gettext('Unversioned') },
		'!' => { name => Wx::gettext('Missing') },
		'~' => { name => Wx::gettext('Obstructed') }
	);

	# Add a zero count key for subversion status hash
	$SVN_STATUS{$_}->{count} = 0 for keys %SVN_STATUS;

	# Retrieve the state of the checkboxes
	my $show_normal  = $self->{show_normal}->IsChecked  ? 1 : 0;
	my $show_unversioned = $self->{show_unversioned}->IsChecked ? 1 : 0;
	my $show_ignored     = $self->{show_ignored}->IsChecked     ? 1 : 0;

	my $index = 0;
	my $list  = $self->{list};
	my $model = $self->{model};
	for my $rec (@$model) {
		my $status      = $rec->{status};
		my $file_status = $SVN_STATUS{$status};
		if ( defined $file_status ) {

			if ( $show_normal or $status ne ' ' ) {

				if ( $show_unversioned or $status ne '?' ) {
					if ( $show_ignored or $status ne 'I' ) {

						# Add a version control file to the list
						$list->InsertStringItem( $index, $rec->{current} );
						$list->SetItem( $index,   1, $rec->{author} );
						$list->SetItem( $index,   2, $file_status->{name} );
						$list->SetItem( $index++, 3, $rec->{file} );
					}
				}
			}

		}
		$file_status->{count}++;
	}

	# Show Subversion statistics
	my $message = '';
	for my $status ( sort keys %SVN_STATUS ) {
		my $svn_status = $SVN_STATUS{$status};
		next if $svn_status->{count} == 0;
		if ( length($message) > 0 ) {
			$message .= Wx::gettext(', ');
		}
		$message .= sprintf( '%s=%d', $svn_status->{name}, $svn_status->{count} );
	}
	$self->{status}->SetLabel($message);

	# Tidy the list
	Padre::Util::tidy_list($list);

	return 1;
}

sub on_show_unversioned_click {
	$_[0]->render;
}

sub on_show_normal_click {
	$_[0]->render;
}

sub on_show_ignored_click {
	$_[0]->render;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
