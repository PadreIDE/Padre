package Padre::Wx::Directory::SearchCtrl;

use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.41';
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
	my $self  = $class->SUPER::new(
		$panel, -1, '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
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
	$_[0]->parent->main;
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
	if ( defined($current_project) and defined($last_project) and $last_project ne $current_project ) {

		$self->{use_cache} = 1;
		my $value = $self->{CACHED}->{$current_project}->{value};
		$self->SetValue(defined $value ? $value : '');

		######################################################################
		# (Un)Checks current project Searcher Menu Skips options
		my $skips_hidden = $self->{_skip_hidden}->{ $current_project };
		my $skips_vcs = $self->{_skip_vcs}->{ $current_project };

		$self->{skip_hidden}->Check( defined $skips_hidden ? $skips_hidden : 1 );
		$self->{skip_vcs}->Check( defined $skips_vcs ? $skips_vcs : 1 );
	}
}

################################################################################
# _search                                                                      #
#                                                                              #
# Searchs recursively per items that matchs the REGEX typed in search field,   #
# showing all items matched below the ROOT project directory will all the      #
# folders that paths to them expanded                                          #
#                                                                              #
################################################################################
sub _search {
	my ( $self, $node ) = @_;
	my $parent = $self->parent;
	my $current_project = $parent->_current_project;

	# Fetch the ignore criteria
	my $project = $self->parent->current->project;
	my $rule    = $project ? $project->ignore_rule : undef;

	######################################################################
	# Check if it is to use the Cached search (in case of a project
	# switching)
	if ( $self->{use_cache} ) {
		delete $self->{use_cache};
		if ( defined $self->{CACHED}->{$current_project}->{Data} ) {
			return $self->_display_cached_search(
				$node,
				$self->{CACHED}->{$current_project}->{Data},
			);
		}
	}

	######################################################################
	# If there is a Cached Word (in case that the user is still typing)
	if ( my $last_word = $self->{CACHED}->{$current_project}->{value} ){

		######################################################################
		# Quotes meta characters
		$last_word = quotemeta($last_word);;

		######################################################################
		# If the typed word contains the cached word, use Cached result to do
		# the new search and returns the result
		if ( $self->GetValue =~ /$last_word/i ) {
			return $self->_search_in_cache( $node, $self->{CACHED}->{$current_project}->{Data} );
		}
	}

	######################################################################
	# Quotes meta characters
	my $word = quotemeta( $self->GetValue );

	######################################################################
	# Gets the node's data and generates its path
	my $browser = $self->browser;
	my $node_data = $browser->GetPlData( $node );
	my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	######################################################################
	# Opens the current directory and sort its items by type and name
	my ($dirs, $files) = $browser->readdir( $path );

	# Filter the file list by the search criteria (but not the dir list)
	@$files = grep { $_ =~ /$word/i } @$files;

	######################################################################
	# Search recursively inside each folder of the current folder
	my $found  = scalar @$files;
	my @result = ();
	foreach ( @$dirs ) {
		my %temp = (
			name => $_,
			dir  => $path,
			type => 'folder',
		);

		# Are we ignoring this directory
		if ( $self->{skip_hidden}->IsChecked ) {
			if ( $rule ) {
				local $_ = \%temp;
				unless ( $rule->() ) {
					next;
				}
			} elsif ( $temp{name} =~ /^\./ ) {
				next;
			}
		}

		# Skips VCS folders if selected to
		if ( $self->{skip_vcs}->IsChecked ) {
			if ( $temp{name} =~ /^(cvs|blib|\.(svn|git))$/i ) {
				next;
			}
		}
		
		######################################################################
		# Creates each folder node
		my $new_folder = $browser->AppendItem(
			$node, $_, -1, -1,
			Wx::TreeItemData->new( {
				dir  => $path,
				name => $_,
				type => 'folder',
			} )
		);
		$browser->SetItemImage(
			$new_folder,
			$browser->{file_types}->{folder},
			Wx::wxTreeItemIcon_Normal,
		);

		######################################################################
		# Deletes the folder node if any file below it was found
		if ( @{$temp{data}} = $self->_search($new_folder) ) {
			$found = 1;
			push @result, \%temp;
		} else{
			$browser->Delete($new_folder);
		}
	}

	######################################################################
	# Adds each matched file
	foreach ( @$files ) {
		my $new_elem = $browser->AppendItem(
			$node, $_, -1,-1,
			Wx::TreeItemData->new( {
				name => $_,
				dir  => $path,
				type => 'package',
			} )
		);
		$browser->SetItemImage(
			$new_elem,
			$browser->{file_types}->{package},
			Wx::wxTreeItemIcon_Normal,
		);
		push @result, {
			name => $_,
			dir  => $path,
			type => 'package',
		};
	}

	######################################################################
	# Returns 1 if any file above this path node was found or 0 and
	# deletes parent node if none
	return @result;
}

################################################################################
# _search_in_cache                                                             #
#                                                                              #
# Searchs recursively per items that matchs the REGEX typed in search field,   #
# using the cached result. Only when the new word contains the lastest         #
# searched word                                                                #
#                                                                              #
################################################################################
sub _search_in_cache {
	my ( $self, $node, $data ) = @_;
	my $browser = $self->browser;

	######################################################################
	# Quotes meta characters
	my $word = quotemeta($self->GetValue);

	my @result = ();
	######################################################################
	# Goes thought each item from $data, if is a folder , searchs
	# recursively inside it, if is a file tries to match its name
	foreach ( @$data ) {

		######################################################################
		# If it is a folder, searchs recursively below it
		if ( defined $_->{data} ) {
			my %temp = (
				dir => $_->{dir},
				name => $_->{name},
				type => $_->{type}
			);

			######################################################################
			# Creates each folder node
			my $new_folder = $browser->AppendItem(
				$node, $_->{name}, -1, -1,
				Wx::TreeItemData->new( {
					dir  => $_->{dir},
					name => $_->{name},
					type => $_->{type},
				} )
			);
			
			$browser->SetItemImage(
				$new_folder,
				$browser->{file_types}->{folder},
				Wx::wxTreeItemIcon_Normal,
			);

			######################################################################
			# Deletes the folder node if any file below it was found
			if ( @{$temp{data}} = $self->_search_in_cache( $new_folder, $_->{data} ) ) {
				push @result, \%temp;
			} else{
				$browser->Delete($new_folder);
			}
		}
		else {
			######################################################################
			# Adds each matched file
			if ( $_->{name} =~ /$word/i ) {

				my $new_elem = $browser->AppendItem(
					$node, $_->{name}, -1,-1,
					Wx::TreeItemData->new( {
						name => $_->{name},
						dir  => $_->{dir},
						type => 'package',
					} )
				);
				$browser->SetItemImage(
					$new_elem,
					$browser->{file_types}->{package},
					Wx::wxTreeItemIcon_Normal,
				);

				push @result, {
					name => $_->{name},
					dir  => $_->{dir},
					type => 'package',
				};
			}
		}
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
################################################################################
sub _setup_menu {
	my $self = shift;
	my $current_project = $self->parent->_current_project;
	my $menu = Wx::Menu->new;
	
	######################################################################
	# Skip hidden files
	$self->{skip_hidden} = $menu->AppendCheckItem( -1, Wx::gettext( 'Skip hidden files' ) );
	$self->{skip_hidden}->Check(1);

	Wx::Event::EVT_MENU(
		$self,
		$self->{skip_hidden},
		sub {
			$self->{_skip_hidden}->{ $self->parent->_current_project } = $self->{skip_hidden}->IsChecked ? 1 : 0;
		},
	);

	######################################################################
	# Skip CVS / .svn / blib and .git folders
	$self->{skip_vcs} = $menu->AppendCheckItem( -1, Wx::gettext( 'Skip CVS/.svn/.git/blib folders' ));
	$self->{skip_vcs}->Check(1);

	Wx::Event::EVT_MENU(
		$self,
		$self->{skip_vcs},
		sub {
			$self->{_skip_vcs}->{ $self->parent->_current_project } = $self->{skip_vcs}->IsChecked ? 1 : 0;
		},
	);

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
	my $self = shift;

	my $parent  = $self->parent;
	my $browser = $self->browser;
	my $value   = $self->GetValue;
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

	# Lock the gui here to make the updates look slicker
	# The locker holds the gui freeze until the update is done.
	my $locker = $self->main->freezer;

	######################################################################
	# Cleans the Directory Browser window to show the result
	my $root = $browser->GetRootItem;
	$browser->DeleteChildren( $root );

	######################################################################
	# Searchs below the root path and caches it
	@{$self->{CACHED}->{ $current_project }->{Data}} = $self->_search($root);

	######################################################################
	# Caches the searched word to the project
	$self->{CACHED}->{ $current_project }->{value} = $value;

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
