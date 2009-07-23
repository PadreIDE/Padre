package Padre::Wx::Directory::SearchCtrl;

use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.40';
our @ISA     = 'Wx::SearchCtrl';

################################################################################
# new                                                                          #
#                                                                              #
# Creates a new Seacher object and shows a search text field above directory   #
# browser                                                                      #
################################################################################
sub new {
	my $class = shift;
	my $panel = shift;

	my $self = $class->SUPER::new(
			$panel, -1, '',
			Wx::wxDefaultPosition, Wx::wxDefaultSize, Wx::wxTE_PROCESS_ENTER
		);

	######################################################################
	# Caches each project search WORD and result
	$self->{CACHED} = {};

	######################################################################
	# Text that is showed when the search field is empty
	$self->SetDescriptiveText(Wx::gettext('Search'));

	######################################################################
	# Setups the search box menu
	$self->SetMenu($self->_setup_menu);

	######################################################################
	# Setups events related with the search field
	$self->_setup_events;

	return $self;
}

################################################################################
# main                                                                         #
#                                                                              #
# Returns the main object reference                                            #
#                                                                              #
################################################################################
sub main {
	$_[0]->GetGrandParent->GetParent;
}

################################################################################
# parent                                                                       #
#                                                                              #
# Returns the Directory Panel object reference                                 #
#                                                                              #
################################################################################
sub parent {
	$_[0]->GetParent;
}

################################################################################
# browser                                                                      #
#                                                                              #
# Returns the Directory Browser object reference                               #
#                                                                              #
################################################################################
sub browser {
	$_[0]->parent->_browser;
}

################################################################################
# clear                                                                        #
#                                                                              #
# Clears search field content                                                  #
#                                                                              #
################################################################################
sub clear {
	my $self = shift;
	delete $self->{CACHED}->{$self->parent->_current_project};
	$self->SetValue('');
	return;
}

################################################################################
# update_gui                                                                   #
#                                                                              #
# Updates the gui if needed                                                    #
#                                                                              #
# Called by Directory.pm                                                       #
#                                                                              #
################################################################################
sub update_gui {
	my $self = shift;
	my $parent = $self->parent;

	######################################################################
	# Gets the last and current actived projects
	my $last_project = $parent->_last_project;
	my $current_project = $parent->_current_project;

	######################################################################
	# Compares if they are not the same, if not updates search field
	# content
	if ( defined($current_project) and (not defined($last_project) or $last_project ne $current_project ) ) {
		$self->{use_cache} = 1;
		my $value = $self->{CACHED}->{$current_project}->{value};
		$self->SetValue(defined $value ? $value : '');
	}
}

################################################################################
# _search                                                                      #
#                                                                              #
# Serachs recursively per items that matchs the REGEX typed in search field,   #
# showing all items matched below the ROOT project directory will all the      #
# folders that paths to them expanded                                          #
#                                                                              #
################################################################################
sub _search {
	my ( $self, $node ) = @_;
	my $parent = $self->parent;
	my $current_project = $parent->_current_project;

	######################################################################
	# Check if it is to use the Cached search (in case of a project
	# switching)
	if ( $self->{use_cache} ) {
		delete $self->{use_cache};
		return $self->_display_cached_search( $node, $self->{CACHED}->{$current_project}->{Data} );
	}

	my $word = $self->GetValue;
	######################################################################
	# Clears '\' words or trailing '\' and returns if the word is null
	$word =~ s/^\\$//g;
	$word =~ s/\\$//g;
	return unless $word;

	######################################################################
	# Gets the node's data and generates its path
	my $browser = $self->browser;
	my $node_data = $browser->GetPlData( $node );
	my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	######################################################################
	# Opens the current directory and sort its items by type and name
	opendir( my $dh, $path ) or return;
	my @items = sort { ( -d File::Spec->catfile( $path, $b ) ? 1 : 0 ) <=> ( -d File::Spec->catfile( $path, $a ) ? 1 : 0 ) } sort { lc($a) cmp lc($b) } grep { not $browser->{SKIP}->{$_} } readdir $dh;
	closedir $dh;

	######################################################################
	# Hidden files
	@items = grep { $_ !~ /^\./ } @items;

	######################################################################
	# Files that matchs and Dirs arrays
	my @dirs  = grep { -d File::Spec->catfile( $path, $_ ) } @items;
	my $found = my @files = grep { $_ =~ /$word/i } grep { not -d File::Spec->catfile( $path, $_ ) } @items;
	my @result;

	######################################################################
	# Search recursively inside each folder of the current folder
	for (@dirs) {
		my %temp = ( name => $_, dir => $path, type => 'folder' );
		######################################################################
		# Creates each folder node
		my $new_folder = $browser->AppendItem(
					$node, $_, -1, -1,
					Wx::TreeItemData->new( { dir => $path, name => $_, type => 'folder' } )
				);
		$browser->SetItemImage( $new_folder, $browser->{file_types}->{folder}, Wx::wxTreeItemIcon_Normal );

		######################################################################
		# Deletes the folder node if any file below it was found
		if ( @{$temp{data}} = $self->_search($new_folder) ) {
			$found = 1;
			push(@result,\%temp);
		} else{
			$browser->Delete($new_folder);
		}
	}

	######################################################################
	# Adds each matched file
	for (@files) {
		my $new_elem = $browser->AppendItem(
				$node, $_, -1,-1,
				Wx::TreeItemData->new( { dir => $path, name => $_, type => 'package' } )
			);
		$browser->SetItemImage( $new_elem, $browser->{file_types}->{package}, Wx::wxTreeItemIcon_Normal );
		my %temp = ( name => $_, dir => $path, type => 'package');
		push(@result,\%temp);
	}
	
	######################################################################
	# Returns 1 if any file above this path node was found or 0 and
	# deletes parent node if none
	return @result;
}

################################################################################
# _display_cached_search                                                       #
#                                                                              #
# If was switched between projects, and the search is actived, use the cached  #
# result set instead of doing the search again                                 #
#                                                                              #
################################################################################
sub _display_cached_search {
	my ( $self, $node, $data ) = @_;
	my $browser = $self->parent->_browser;
	my $node_data = $browser->GetPlData( $node );
	my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	######################################################################
	# Files that matchs and Dirs arrays
	my @dirs = grep { $_->{type} eq 'folder' } @{$data};
	my @files = grep { $_->{type} eq 'package' } @{$data};

	######################################################################
	# Search recursively inside each folder of the current folder
	for (@dirs) {
		######################################################################
		# Creates each folder node
		my $new_folder = $browser->AppendItem(
					$node, $_->{name}, -1, -1,
					Wx::TreeItemData->new( { dir => $path, name => $_->{name}, type => 'folder' } )
				);
		$browser->SetItemImage( $new_folder, $browser->{file_types}->{folder}, Wx::wxTreeItemIcon_Normal );

		######################################################################
		# Deletes the folder node if any file below it was found
		$self->_search($new_folder, $_->{Data});
	}

	######################################################################
	# Adds each matched file
	for (@files) {
		my $new_elem = $browser->AppendItem(
				$node, $_->{name}, -1,-1,
				Wx::TreeItemData->new( { dir => $path, name => $_->{name}, type => 'package' } )
			);
		$browser->SetItemImage( $new_elem, $browser->{file_types}->{package}, Wx::wxTreeItemIcon_Normal );
	}
	return @{$data};
}

################################################################################
#                                                                              #
#                                                                              #
#                                                                              #
#                               SETUP FUNCTIONS                                #
#                                                                              #
#               Runned only when a new Seacher object is created               #
#                                                                              #
#                                                                              #
#                                                                              #
################################################################################

################################################################################
# _setup_events                                                                #
#                                                                              #
# Setups the Directory Searcher Events and the respective action               #
#                                                                              #
################################################################################
sub _setup_events {
	my $self = shift;
	Wx::Event::EVT_TEXT(
		$self, $self,
		\&_on_text
	);

	Wx::Event::EVT_SEARCHCTRL_CANCEL_BTN(
		$self, $self,
		\&_on_searchctrl_cancel_btn
	);
}

################################################################################
# _setup_menu                                                                  #
#                                                                              #
# Setups the Searcher menu                                                     #
#                                                                              #
# TODO                                                                         #
################################################################################
sub _setup_menu {
	my $self = shift;
	my $menu = Wx::Menu->new;
	Wx::Event::EVT_MENU($self, $menu->AppendCheckItem( -1, Wx::gettext( 'Skip hidden files' ) ),sub {},);
	return $menu;
}

################################################################################
#                                                                              #
#                                                                              #
#                                                                              #
#                          DIRECTORY SEARCHER EVENTS                           #
#                                                                              #
#                Executed when an pre estabilished event occurs                #
#                                                                              #
#                                                                              #
#                                                                              #
################################################################################

################################################################################
# _on_text                                                                     #
#                                                                              #
# If it is a project, caches search field content while it is typed and        #
# searchs for files that matchs the type word                                  #
#                                                                              #
################################################################################
sub _on_text {
	my ( $self, $event ) = @_;

	my $parent = $self->parent;
	my $browser = $self->browser;
	my $value = $self->GetValue;
	my $current_project = $parent->_current_project;

	######################################################################
	# If there is no project opened returns
	return unless $current_project;

	######################################################################
	# If nothing is typed hides the Cancel button and sets that the search
	# is not in use
	unless ( $value ){

		######################################################################
		# Hides Cancel Button
		$self->ShowCancelButton(0);

		######################################################################
		# Sets that the search for this project was just used and is not in
		# use anymore
		$self->{just_used}->{ $current_project } = 1;
		delete $self->{in_use}->{ $current_project };
		delete $self->{CACHED}->{ $current_project };

		######################################################################
		# Updates the Directory Browser window
		$self->parent->_browser->update_gui;

		return;
	}

	######################################################################
	# Sets that the search is in use
	$self->{in_use}->{ $current_project } = 1;

	######################################################################
	# Caches the searched word to the project
	$self->{CACHED}->{ $current_project }->{value} = $value;

	######################################################################
	# Cleans the Directory Browser window to show the result
	my $root = $browser->GetRootItem;
	$browser->DeleteChildren( $root );

	######################################################################
	# Searchs below the root path and caches it
	@{$self->{CACHED}->{ $current_project }->{Data}} = $self->_search($root);

	######################################################################
	# Expands all the folders to the files matched
	$browser->ExpandAll;

	######################################################################
	# Shows the Cancel button
	$self->ShowCancelButton(1);

}

################################################################################
# _on_searchctrl_cancel_btn                                                    #
#                                                                              #
# Clears the search field content                                              #
#                                                                              #
# Called when the search field Cancel button is pressed                        #
#                                                                              #
################################################################################
sub _on_searchctrl_cancel_btn {
	my ( $self, $event ) = @_;
	$self->SetValue('');
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
