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

use constant {
	RED        => Wx::Colour->new('red'),
	DARK_GREEN => Wx::Colour->new( 0x00, 0x90, 0x00 ),
	BLUE       => Wx::Colour->new('blue'),
	GRAY       => Wx::Colour->new('gray'),
	BLACK      => Wx::Colour->new('black'),
};

# Constructor
sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;
	my $self  = $class->SUPER::new($panel);

	# Set the bitmap button icons
	$self->{commit}->SetBitmapLabel( Padre::Wx::Icon::find('actions/document-save') );
	$self->{add}->SetBitmapLabel( Padre::Wx::Icon::find('actions/list-add') );
	$self->{delete}->SetBitmapLabel( Padre::Wx::Icon::find('actions/list-remove') );
	$self->{revert}->SetBitmapLabel( Padre::Wx::Icon::find('actions/edit-undo') );
	$self->{refresh}->SetBitmapLabel( Padre::Wx::Icon::find('actions/view-refresh') );

	# Set up column sorting
	$self->{sortcolumn}  = 0;
	$self->{sortreverse} = 1;

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
	$self->{show_unversioned}->SetValue(0);
	$self->{show_ignored}->SetValue(0);

	# Hide vcs command buttons at startup
	$self->{commit}->Hide;
	$self->{add}->Hide;
	$self->{delete}->Hide;
	$self->{revert}->Hide;

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
	$_[0]->{list}->DeleteAllItems;
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

	# Flush old results
	$self->clear;

	# Do not display anything where there is no open documents
	return unless $document;

	# Shortcut if there is nothing in the document to do
	if ( $document->is_unused ) {
		$self->{status}->SetLabel( Wx::gettext('Current file is not saved in a version control system') );
		return;
	}

	# Retrieve project version control system
	my $vcs = $document->project->vcs;

	# No version control system?
	unless ($vcs) {
		$self->{status}->SetLabel( Wx::gettext('Current file is not in a version control system') );
		return;
	}

	# Only subversion is supported at the moment
	if ( $vcs ne Padre::Constant::SUBVERSION ) {
		$self->{status}
			->SetLabel( sprintf( Wx::gettext('%s version control project support is not currently supported'), $vcs ) );
		return;
	}

	#TODO support GIT

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
	# $self->clear;

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
	my $show_normal      = $self->{show_normal}->IsChecked      ? 1 : 0;
	my $show_unversioned = $self->{show_unversioned}->IsChecked ? 1 : 0;
	my $show_ignored     = $self->{show_ignored}->IsChecked     ? 1 : 0;

	my $index = 0;
	my $list  = $self->{list};
	my $model = $self->{model};


	my @model = @$model;
	if ( $self->{sortcolumn} == 0 ) {

		# Sort by revision
		@model = sort { $a->{current} cmp $b->{current} } @model;
	} elsif ( $self->{sortcolumn} == 1 ) {

		# Sort by author
		@model = sort { $a->{author} cmp $b->{author} } @model;
	} elsif ( $self->{sortcolumn} == 2 ) {

		# Sort by status
		@model = sort { $a->{status} cmp $b->{status} } @model;
	} elsif ( $self->{sortcolumn} == 3 ) {

		# Sort by path
		@model = sort { $a->{path} cmp $b->{path} } @model;
	}
	$self->{model} = \@model;

	if ( $self->{sortreverse} ) {

		# reverse the sorting
		@model = reverse @model;
	}

	my $model_index = 0;
	for my $rec (@model) {
		my $status      = $rec->{status};
		my $path_status = $SVN_STATUS{$status};
		if ( defined $path_status ) {

			if ( $show_normal or $status ne ' ' ) {

				if ( $show_unversioned or $status ne '?' ) {
					if ( $show_ignored or $status ne 'I' ) {

						# Add a version control path to the list
						$list->InsertStringItem( $index, $rec->{current} );
						$list->SetItemData( $index, $model_index );
						$list->SetItem( $index, 1, $rec->{author} );
						$list->SetItem( $index, 2, $path_status->{name} );

						my $color;
						if ( $status eq ' ' ) {
							$color = DARK_GREEN;
						} elsif ( $status eq 'A' or $status eq 'D' ) {
							$color = RED;
						} elsif ( $status eq 'M' ) {
							$color = BLUE;
						} elsif ( $status eq 'I' ) {
							$color = GRAY;
						} else {
							$color = BLACK;
						}
						$list->SetItemTextColour( $index, $color );
						$list->SetItem( $index++, 3, $rec->{path} );
					}
				}
			}

		}
		$path_status->{count}++;
		$model_index++;
	}

	# Select the first item
	if ( $list->GetItemCount > 0 ) {
		$list->SetItemState( 0, Wx::LIST_STATE_SELECTED, Wx::LIST_STATE_SELECTED );
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

	my $svn_command_shown = $list->GetSelectedItemCount > 0;
	$self->{commit}->Show($svn_command_shown);
	$self->{add}->Show($svn_command_shown);
	$self->{delete}->Show($svn_command_shown);
	$self->{revert}->Show($svn_command_shown);

	$self->Layout;

	# Tidy the list
	Padre::Util::tidy_list($list);

	return 1;
}

# Called when a version control list column is clicked
sub on_list_column_click {
	my ( $self, $event ) = @_;

	my $column   = $event->GetColumn;
	my $prevcol  = $self->{sortcolumn};
	my $reversed = $self->{sortreverse};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{sortcolumn}  = $column;
	$self->{sortreverse} = $reversed;

	$self->render;

	return;
}

sub on_list_item_activated {
	my ( $self, $event ) = @_;

	my $main     = $self->main;
	my $rec      = $self->{model}->[ $self->{list}->GetItemData( $event->GetIndex ) ] or return;
	my $filename = $rec->{fullpath};
	eval {

		# Try to open the file now
		if ( my $id = $main->editor_of_file($filename) ) {
			my $page = $main->notebook->GetPage($id);
			$page->SetFocus;
		} else {
			$main->setup_editors($filename);
		}
	};
	$main->error( Wx::gettext('Error while trying to perform Padre action') ) if $@;
}

# Called when "Show normal" checkbox is clicked
sub on_show_normal_click {
	$_[0]->render;
}

# Called when "Show unversional" checkbox is clicked
sub on_show_unversioned_click {
	$_[0]->render;
}

# Called when "Show ignored" checkbox is clicked
sub on_show_ignored_click {
	$_[0]->render;
}

# Called when "Commit" button is clicked
sub on_commit_click {
	$_[0]->main->error('on_commit_click not implemented');
}

# Called when "Add" button is clicked
sub on_add_click {
	my $self = shift;

	my $main           = $self->main;
	my $list           = $self->{list};
	my $selected_index = $list->GetNextItem( -1, Wx::LIST_NEXT_ALL, Wx::LIST_STATE_SELECTED );
	return if $selected_index == -1;
	my $rec = $self->{model}->[ $list->GetItemData($selected_index) ] or return;
	my $filename = $rec->{fullpath};

	return
		unless $main->yes_no(
		sprintf( Wx::gettext("Do you want to add '%s' to your repository"), $filename ),
		Wx::gettext('Add file to repository?')
		);
	$main->error('on_add_click not implemented');
}

# Called when "Delete" checkbox is clicked
sub on_delete_click {
	my $self           = shift;
	my $main           = $self->main;
	my $list           = $self->{list};
	my $selected_index = $list->GetNextItem( -1, Wx::LIST_NEXT_ALL, Wx::LIST_STATE_SELECTED );
	return if $selected_index == -1;
	my $rec = $self->{model}->[ $list->GetItemData($selected_index) ] or return;
	my $filename = $rec->{fullpath};

	return
		unless $main->yes_no(
		sprintf( Wx::gettext("Do you want to delete '%s' from your repository"), $filename ),
		Wx::gettext('Delete file from repository??')
		);
	$main->error('on_delete_click not implemented');
}

# Called when "Revert" button is clicked
sub on_revert_click {
	my $self           = shift;
	my $main           = $self->main;
	my $list           = $self->{list};
	my $selected_index = $list->GetNextItem( -1, Wx::LIST_NEXT_ALL, Wx::LIST_STATE_SELECTED );
	return if $selected_index == -1;
	my $rec = $self->{model}->[ $list->GetItemData($selected_index) ] or return;
	my $filename = $rec->{fullpath};

	return
		unless $main->yes_no(
		sprintf( Wx::gettext("Do you want to revert changes to '%s'"), $filename ),
		Wx::gettext('Revert changes?')
		);
	$main->error('on_revert_click not implemented');
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
