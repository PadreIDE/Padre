package Padre::Wx::VCS;

use 5.008;
use strict;
use warnings;
use Padre::Feature        ();
use Padre::Role::Task     ();
use Padre::Wx             ();
use Padre::Wx::Util       ();
use Padre::Wx::Role::View ();
use Padre::Wx::FBP::VCS   ();
use Padre::Task::VCS      ();
use Padre::Logger;

our $VERSION = '0.94';
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
	my $panel = shift || $main->right;
	my $self  = $class->SUPER::new($panel);

	# Set the bitmap button icons
	$self->{add}->SetBitmapLabel( Padre::Wx::Icon::find('actions/list-add') );
	$self->{delete}->SetBitmapLabel( Padre::Wx::Icon::find('actions/list-remove') );
	$self->{update}->SetBitmapLabel( Padre::Wx::Icon::find('actions/stock_update-data') );
	$self->{commit}->SetBitmapLabel( Padre::Wx::Icon::find('actions/document-save') );
	$self->{revert}->SetBitmapLabel( Padre::Wx::Icon::find('actions/edit-undo') );
	$self->{refresh}->SetBitmapLabel( Padre::Wx::Icon::find('actions/view-refresh') );

	# Set up column sorting
	$self->{sort_column} = 0;
	$self->{sort_desc}   = 1;

	# Setup columns
	my @column_headers = (
		Wx::gettext('Status'),
		Wx::gettext('Path'),
		Wx::gettext('Author'),
		Wx::gettext('Revision'),
	);
	my $index = 0;
	for my $column_header (@column_headers) {
		$self->{list}->InsertColumn( $index++, $column_header );
	}

	# Column ascending/descending image
	my $images = Wx::ImageList->new( 16, 16 );
	$self->{images} = {
		asc => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_GO_UP',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		desc => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_GO_DOWN',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
	};
	$self->{list}->AssignImageList( $images, Wx::IMAGE_LIST_SMALL );

	# Tidy the list
	Padre::Wx::Util::tidy_list( $self->{list} );

	# Update the checkboxes with their corresponding values in the
	# configuration
	my $config = $main->config;
	$self->{show_normal}->SetValue( $config->vcs_normal_shown );
	$self->{show_unversioned}->SetValue( $config->vcs_unversioned_shown );
	$self->{show_ignored}->SetValue( $config->vcs_ignored_shown );

	# Hide vcs command buttons at startup
	$self->{commit}->Hide;
	$self->{add}->Hide;
	$self->{delete}->Hide;
	$self->{revert}->Hide;
	$self->{update}->Hide;

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'right';
}

sub view_label {
	Wx::gettext('Version Control');
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

# Clear everything...
sub clear {
	my $self = shift;

	$self->{list}->DeleteAllItems;
	$self->_show_command_bar(0);

	return;
}

# Nothing to implement here
sub relocale {
	return;
}

sub refresh {
	my $self    = shift;
	my $current = shift or return;
	my $command = shift || Padre::Task::VCS::VCS_STATUS;

	my $document = $current->document;

	# Abort any in-flight checks
	$self->task_reset;

	# Flush old results
	$self->clear;

	# Do not display anything where there is no open documents
	return unless $document;

	# Shortcut if there is nothing in the document to do
	if ( $document->is_unused ) {
		$self->{status}->SetValue( Wx::gettext('Current file is not saved in a version control system') );
		return;
	}

	# Retrieve project version control system
	my $vcs = $document->project->vcs;

	# No version control system?
	unless ($vcs) {
		$self->{status}->SetValue( Wx::gettext('Current file is not in a version control system') );
		return;
	}

	# Not supported VCS check
	if ( $vcs ne Padre::Constant::SUBVERSION and $vcs ne Padre::Constant::GIT ) {
		$self->{status}->SetValue( sprintf( Wx::gettext('%s version control is not currently available'), $vcs ) );
		return;
	}


	# Start a background VCS status task
	$self->task_request(
		task     => 'Padre::Task::VCS',
		command  => $command,
		document => $document,
	);

	return 1;
}

sub task_finish {
	my $self = shift;
	my $task = shift;
	$self->{model} = Params::Util::_ARRAY0( $task->{model} ) or return;
	$self->{vcs} = $task->{vcs} or return;

	$self->render;
}

sub render {
	my $self = shift;

	# Clear if needed. Please note that this is needed
	# for sorting
	$self->clear;

	return unless $self->{model};

	# Subversion status codes
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

	# GIT status code
	my %GIT_STATUS = (
		' ' => { name => Wx::gettext('Unmodified') },
		'M' => { name => Wx::gettext('Modified') },
		'A' => { name => Wx::gettext('Added') },
		'D' => { name => Wx::gettext('Deleted') },
		'R' => { name => Wx::gettext('Renamed') },
		'C' => { name => Wx::gettext('Copied') },
		'U' => { name => Wx::gettext('Updated but unmerged') },
		'?' => { name => Wx::gettext('Unversioned') },
	);

	my %vcs_status = $self->{vcs} eq Padre::Constant::SUBVERSION ? %SVN_STATUS : %GIT_STATUS;

	# Add a zero count key for VCS status hash
	$vcs_status{$_}->{count} = 0 for keys %vcs_status;

	# Retrieve the state of the checkboxes
	my $show_normal      = $self->{show_normal}->IsChecked      ? 1 : 0;
	my $show_unversioned = $self->{show_unversioned}->IsChecked ? 1 : 0;
	my $show_ignored     = $self->{show_ignored}->IsChecked     ? 1 : 0;

	my $index = 0;
	my $list  = $self->{list};

	$self->_sort_model(%vcs_status);
	my $model = $self->{model};

	my $model_index = 0;
	for my $rec (@$model) {
		my $status      = $rec->{status};
		my $path_status = $vcs_status{$status};
		if ( defined $path_status ) {

			if ( $show_normal or $status ne ' ' ) {

				if ( $show_unversioned or $status ne '?' ) {
					if ( $show_ignored or $status ne 'I' ) {

						# Add a version control path to the list
						$list->InsertImageStringItem( $index, $path_status->{name}, -1 );
						$list->SetItemData( $index, $model_index );
						$list->SetItem( $index, 1, $rec->{path} );
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

						$list->SetItem( $index,   2, $rec->{author} );
						$list->SetItem( $index++, 3, $rec->{revision} );
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
	for my $status ( sort keys %vcs_status ) {
		my $vcs_status_obj = $vcs_status{$status};
		next if $vcs_status_obj->{count} == 0;
		if ( length($message) > 0 ) {
			$message .= Wx::gettext(', ');
		}
		$message .= sprintf( '%s=%d', $vcs_status_obj->{name}, $vcs_status_obj->{count} );
	}
	$self->{status}->SetValue($message);

	$self->_show_command_bar( $list->GetItemCount > 0 )
		if $self->main->config->vcs_enable_command_bar;

	# Update the list sort image
	$self->set_icon_image( $self->{sort_column}, $self->{sort_desc} );

	# Tidy the list
	Padre::Wx::Util::tidy_list($list);

	return 1;
}

sub _show_command_bar {
	my ( $self, $shown ) = @_;

	$self->{commit}->Show($shown);
	$self->{add}->Show($shown);
	$self->{delete}->Show($shown);
	$self->{revert}->Show($shown);
	$self->{update}->Show($shown);
	$self->Layout;
}

sub _sort_model {
	my ( $self, %vcs_status ) = @_;

	my @model = @{ $self->{model} };
	if ( $self->{sort_column} == 0 ) {

		# Sort by status
		@model = sort { $vcs_status{ $a->{status} }{name} cmp $vcs_status{ $b->{status} }{name} } @model;

	} elsif ( $self->{sort_column} == 1 ) {

		# Sort by path
		@model = sort { $a->{path} cmp $b->{path} } @model;
	} elsif ( $self->{sort_column} == 2 ) {

		# Sort by author
		@model = sort { $a->{author} cmp $b->{author} } @model;
	} elsif ( $self->{sort_column} == 3 ) {

		# Sort by revision
		@model = sort { $a->{revision} cmp $b->{revision} } @model;

	}

	if ( $self->{sort_desc} ) {

		# reverse the sorting
		@model = reverse @model;
	}

	$self->{model} = \@model;
}

# Called when a version control list column is clicked
sub on_list_column_click {
	my ( $self, $event ) = @_;

	my $column   = $event->GetColumn;
	my $prevcol  = $self->{sort_column};
	my $reversed = $self->{sort_desc};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{sort_column} = $column;
	$self->{sort_desc}   = $reversed;

	# Reset the previous column sort image
	$self->set_icon_image( $prevcol, -1 );

	$self->render;

	return;
}

sub set_icon_image {
	my ( $self, $column, $image_index ) = @_;

	my $item = Wx::ListItem->new;
	$item->SetMask(Wx::LIST_MASK_IMAGE);
	$item->SetImage($image_index);
	$self->{list}->SetColumn( $column, $item );

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
			$main->setup_editor($filename);
		}

		# Select the next difference after opening the file
		Wx::Event::EVT_IDLE(
			$main,
			sub {
				$main->{diff}->select_next_difference;
				Wx::Event::EVT_IDLE( $main, undef );
			},
		) if Padre::Feature::DIFF_DOCUMENT;

	};
	$main->error( Wx::gettext('Error while trying to perform Padre action') ) if $@;
}

# Called when "Show normal" checkbox is clicked
sub on_show_normal_click {
	my ( $self, $event ) = @_;

	# Save to configuration
	my $config = $self->main->config;
	$config->apply( vcs_normal_shown => $event->IsChecked ? 1 : 0 );
	$config->write;

	# refresh list
	$self->render;
}

# Called when "Show unversioned" checkbox is clicked
sub on_show_unversioned_click {
	my ( $self, $event ) = @_;

	# Save to configuration
	my $config = $self->main->config;
	$config->apply( vcs_unversioned_shown => $event->IsChecked ? 1 : 0 );
	$config->write;

	# refresh list
	$self->render;
}

# Called when "Show ignored" checkbox is clicked
sub on_show_ignored_click {
	my ( $self, $event ) = @_;

	# Save to configuration
	my $config = $self->main->config;
	$config->apply( vcs_ignored_shown => $event->IsChecked ? 1 : 0 );
	$config->write;

	# refresh list
	$self->render;
}

# Called when "Commit" button is clicked
sub on_commit_click {
	my $self = shift;
	my $main = $self->main;

	return
		unless $main->yes_no(
		Wx::gettext("Do you want to commit?"),
		Wx::gettext('Commit file/directory to repository?')
		);

	$main->vcs->refresh( $self->current, Padre::Task::VCS::VCS_COMMIT );
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

	$main->vcs->refresh( $self->current, Padre::Task::VCS::VCS_ADD );
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

	$main->vcs->refresh( $self->current, Padre::Task::VCS::VCS_DELETE );
}

# Called when "Update" button is clicked
sub on_update_click {
	my $self = shift;
	my $main = $self->main;

	$main->vcs->refresh( $main->current, Padre::Task::VCS::VCS_UPDATE );
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

	$main->vcs->refresh( $self->current, Padre::Task::VCS::VCS_REVERT );
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
