package Padre::Wx::Directory::SearchCtrl;

use strict;
use warnings;
use Padre::Current ();
use Padre::Wx      ();

our $VERSION = '0.41';
our @ISA     = 'Wx::SearchCtrl';

# Create a new Search object and show a search text field above the tree
sub new {
	my $class = shift;
	my $panel = shift;
	my $self  = $class->SUPER::new(
		$panel, -1, '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);

	# Caches each project search WORD and result
	$self->{CACHED} = {};

	# Text that is showed when the search field is empty
	$self->SetDescriptiveText( Wx::gettext('Search') );

	# Setups the search box menu
	$self->SetMenu( $self->create_menu );

	# Setups events related with the search field
	Wx::Event::EVT_TEXT(
		$self, $self,
		\&_on_text
	);

	Wx::Event::EVT_SEARCHCTRL_CANCEL_BTN(
		$self, $self,
		sub {
			$self->SetValue('');
		}
	);

	Wx::Event::EVT_SET_FOCUS(
		$self,
		sub {
			$_[0]->parent->refresh;
		},
	);

	return $self;
}

# Returns the Directory Panel object reference
sub parent {
	$_[0]->GetParent;
}

# Returns the main object reference
sub main {
	$_[0]->GetParent->main;
}

# Traverse to the sibling tree widget
sub tree {
	$_[0]->GetParent->tree;
}

sub current {
	Padre::Current->new( main => $_[0]->main );
}

# Called by Directory.pm
sub refresh {
	my $self   = shift;
	my $parent = $self->parent;

	# Gets the last and current actived projects
	my $project_dir  = $parent->project_dir;
	my $previous_dir = $parent->previous_dir;

	# Compares if they are not the same, if not updates search field
	# content
	if (    defined($project_dir)
		and defined($previous_dir)
		and $previous_dir ne $project_dir )
	{
		$self->{use_cache} = 1;
		my $value = $self->{CACHED}->{$project_dir}->{value};
		$self->SetValue( defined $value ? $value : '' );

		# Checks the currently mode view
		my $mode = "sub_" . $parent->mode;
		$self->{$mode}->Check(1);

		# (Un)Checks current project Searcher Menu Skips options
		my $skips_hidden = $self->{_skip_hidden}->{$project_dir};
		my $skips_vcs    = $self->{_skip_vcs}->{$project_dir};

		$self->{skip_hidden}->Check( defined $skips_hidden ? $skips_hidden : 1 );
		$self->{skip_vcs}->Check( defined $skips_vcs       ? $skips_vcs    : 1 );
	}
}

# Searchs recursively per items that matchs the REGEX typed in search field,
# showing all items matched below the ROOT project directory will all the
# folders that paths to them expanded.
sub _search {
	my ( $self, $node ) = @_;
	my $parent      = $self->parent;
	my $project_dir = $parent->project_dir;

	# Fetch the ignore criteria
	my $project = $self->current->project;
	my $rule = $project ? $project->ignore_rule : undef;

	# Check if it is to use the Cached search (in case of a project
	# switching)
	if ( $self->{use_cache} ) {
		delete $self->{use_cache};
		if ( defined $self->{CACHED}->{$project_dir}->{Data} ) {
			return $self->_display_cached_search(
				$node,
				$self->{CACHED}->{$project_dir}->{Data},
			);
		}
	}

	# If there is a Cached Word (in case that the user is still typing)
	if ( my $last_word = $self->{CACHED}->{$project_dir}->{value} ) {

		# Quotes meta characters
		$last_word = quotemeta($last_word);

		# If the typed word contains the cached word, use Cached result to do
		# the new search and returns the result
		if ( $self->GetValue =~ /$last_word/i ) {
			return $self->_search_in_cache(
				$node,
				$self->{CACHED}->{$project_dir}->{Data},
			);
		}
	}

	# Quotes meta characters
	my $word = quotemeta( $self->GetValue );

	# Gets the node's data and generates its path
	my $tree      = $self->tree;
	my $node_data = $tree->GetPlData($node);
	my $path      = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	# Opens the current directory and sort its items by type and name
	my ( $dirs, $files ) = $tree->readdir($path);

	# Accept some regex like characters
	#   ^ = begin with
	#   $ = end with
	#   * = any string
	#   ? = any character
	$word =~ s/^\\\^/^/g;
	$word =~ s/\\\$$/\$/g;
	$word =~ s/\\\*/.*?/g;
	$word =~ s/\\\?/./g;

	# Filter the file list by the search criteria (but not the dir list)
	@$files = grep { $_ =~ /$word/i } @$files;

	# Search recursively inside each folder of the current folder
	my $found  = scalar @$files;
	my @result = ();
	foreach (@$dirs) {
		my %temp = (
			name => $_,
			dir  => $path,
			type => 'folder',
		);

		# Are we ignoring this directory
		if ( $self->{skip_hidden}->IsChecked ) {
			if ($rule) {
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

		# Creates each folder node
		my $new_folder = $tree->AppendItem(
			$node, $_, -1, -1,
			Wx::TreeItemData->new(
				{   dir  => $path,
					name => $_,
					type => 'folder',
				}
			)
		);
		$tree->SetItemImage(
			$new_folder,
			$tree->{file_types}->{folder},
			Wx::wxTreeItemIcon_Normal,
		);

		# Deletes the folder node if any file below it was found
		if ( @{ $temp{data} } = $self->_search($new_folder) ) {
			$found = 1;
			push @result, \%temp;
		} else {
			$tree->Delete($new_folder);
		}
	}

	# Adds each matched file
	foreach (@$files) {
		my $new_elem = $tree->AppendItem(
			$node, $_, -1, -1,
			Wx::TreeItemData->new(
				{   name => $_,
					dir  => $path,
					type => 'package',
				}
			)
		);
		$tree->SetItemImage(
			$new_elem,
			$tree->{file_types}->{package},
			Wx::wxTreeItemIcon_Normal,
		);
		push @result,
			{
			name => $_,
			dir  => $path,
			type => 'package',
			};
	}

	# Returns 1 if any file above this path node was found or 0 and
	# deletes parent node if none
	return @result;
}

# Searchs recursively per items that matchs the REGEX typed in search field,
# using the cached result. Only when the new word contains the lastest
# searched word
sub _search_in_cache {
	my $self = shift;
	my $node = shift;
	my $data = shift;
	my $tree = $self->tree;

	# Quotes meta characters
	my $word = quotemeta( $self->GetValue );

	# Accept some regex like characters
	#   ^ = begin with
	#   $ = end with
	#   * = any string
	#   ? = any character
	$word =~ s/^\\\^/^/g;
	$word =~ s/\\\$$/\$/g;
	$word =~ s/\\\*/.*?/g;
	$word =~ s/\\\?/./g;

	# Goes thought each item from $data, if is a folder , searchs
	# recursively inside it, if is a file tries to match its name
	my @result = ();
	foreach (@$data) {

		# If it is a folder, searchs recursively below it
		if ( defined $_->{data} ) {
			my %temp = (
				dir  => $_->{dir},
				name => $_->{name},
				type => $_->{type}
			);

			# Creates each folder node
			my $new_folder = $tree->AppendItem(
				$node,
				$_->{name},
				$tree->{file_types}->{folder},
				-1,
				Wx::TreeItemData->new(
					{   dir  => $_->{dir},
						name => $_->{name},
						type => $_->{type},
					}
				)
			);

			# Deletes the folder node if any file below it was found
			if ( @{ $temp{data} } = $self->_search_in_cache( $new_folder, $_->{data} ) ) {
				push @result, \%temp;
			} else {
				$tree->Delete($new_folder);
			}
		} else {

			# Adds each matched file
			if ( $_->{name} =~ /$word/i ) {
				my $new_elem = $tree->AppendItem(
					$node,
					$_->{name},
					$tree->{file_types}->{package},
					-1,
					Wx::TreeItemData->new(
						{   name => $_->{name},
							dir  => $_->{dir},
							type => 'package',
						}
					)
				);
				push @result,
					{
					name => $_->{name},
					dir  => $_->{dir},
					type => 'package',
					};
			}
		}
	}

	# Returns 1 if any file above this path node was found or 0 and
	# deletes parent node if none
	return @result;
}

# If was switched between projects, and the search is actived, use the cached
# result set instead of doing the search again
sub _display_cached_search {
	my ( $self, $node, $data ) = @_;
	my $tree      = $self->tree;
	my $node_data = $tree->GetPlData($node);
	my $path      = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	# Files that matchs and Dirs arrays
	my @dirs  = grep { $_->{type} eq 'folder' } @{$data};
	my @files = grep { $_->{type} eq 'package' } @{$data};

	# Search recursively inside each folder of the current folder
	for (@dirs) {

		# Creates each folder node
		my $new_folder = $tree->AppendItem(
			$node,
			$_->{name},
			$tree->{file_types}->{folder},
			-1,
			Wx::TreeItemData->new(
				{   dir  => $path,
					name => $_->{name},
					type => 'folder',
				}
			)
		);

		# Deletes the folder node if any file below it was found
		$self->_search( $new_folder, $_->{Data} );
	}

	# Adds each matched file
	foreach (@files) {
		my $new_elem = $tree->AppendItem(
			$node,
			$_->{name},
			$tree->{file_types}->{package},
			-1,
			Wx::TreeItemData->new(
				{   dir  => $path,
					name => $_->{name},
					type => 'package',
				}
			)
		);
	}

	return @{$data};
}

# Create the dropdown menu attached to the looking glass icon
sub create_menu {
	my $self        = shift;
	my $parent      = $self->parent;
	my $project_dir = $parent->project_dir;
	my $menu        = Wx::Menu->new;

	# Skip hidden files
	$self->{skip_hidden} = $menu->AppendCheckItem(
		-1,
		Wx::gettext('Skip hidden files')
	);
	$self->{skip_hidden}->Check(1);

	Wx::Event::EVT_MENU(
		$self,
		$self->{skip_hidden},
		sub {
			$self->{_skip_hidden}->{$project_dir} = $self->{skip_hidden}->IsChecked ? 1 : 0;
		},
	);

	# Skip CVS / .svn / blib and .git folders
	$self->{skip_vcs} = $menu->AppendCheckItem(
		-1,
		Wx::gettext('Skip CVS/.svn/.git/blib folders')
	);
	$self->{skip_vcs}->Check(1);

	Wx::Event::EVT_MENU(
		$self,
		$self->{skip_vcs},
		sub {
			$self->{_skip_vcs}->{$project_dir} = $self->{skip_vcs}->IsChecked ? 1 : 0;
		},
	);
	$menu->AppendSeparator();

	# Changes the project directory
	$self->{project_dir} = $menu->Append(
		-1,
		Wx::gettext('Change project directory')
	);

	Wx::Event::EVT_MENU(
		$self,
		$self->{project_dir},
		sub {
			$_[0]->parent->_change_project_dir;
		}
	);

	# Changes the Tree mode view
	my $submenu = Wx::Menu->new;
	$self->{sub_tree}     = $submenu->AppendRadioItem( 1, Wx::gettext('Tree listing') );
	$self->{sub_navigate} = $submenu->AppendRadioItem( 2, Wx::gettext('Navigate') );
	$self->{mode} = $menu->AppendSubMenu( $submenu, Wx::gettext('Change listing mode view') );
	$self->{sub_navigate}->Check(1);

	Wx::Event::EVT_MENU(
		$submenu,
		$self->{sub_tree},
		sub {
			$parent->{projects}->{ $parent->project_dir }->{mode} = 'tree';
			$parent->{mode_change} = 1;
			$parent->refresh;
		}
	);

	Wx::Event::EVT_MENU(
		$submenu,
		$self->{sub_navigate},
		sub {
			$parent->{projects}->{ $parent->project_dir }->{mode} = 'navigate';
			$parent->{mode_change} = 1;
			$parent->refresh;
		}
	);

	# Changes the panel side
	$self->{move_panel} = $menu->Append(
		-1,
		Wx::gettext('Move to other panel')
	);

	Wx::Event::EVT_MENU(
		$self,
		$self->{move_panel},
		sub {
			$_[0]->parent->move;
		}
	);

	return $menu;
}

# If it is a project, caches search field content while it is typed and
# searchs for files that matchs the type word
sub _on_text {
	my $self        = shift;
	my $parent      = $self->parent;
	my $tree        = $self->tree;
	my $value       = $self->GetValue;
	my $project_dir = $parent->project_dir or return;

	# If nothing is typed hides the Cancel button
	# and sets that the search is not in use
	unless ($value) {

		# Hides Cancel Button
		$self->ShowCancelButton(0);

		# Sets that the search for this project was just used
		# and is not in use anymore
		$self->{just_used}->{$project_dir} = 1;
		delete $self->{in_use}->{$project_dir};
		delete $self->{CACHED}->{$project_dir};

		# Updates the Directory Browser window
		$self->tree->refresh;

		return;
	}

	# Sets that the search is in use
	$self->{in_use}->{$project_dir} = 1;

	# Lock the gui here to make the updates look slicker
	# The locker holds the gui freeze until the update is done.
	my $locker = Padre::Current->main($self)->freezer;

	# Cleans the Directory Browser window to show the result
	my $root = $tree->GetRootItem;
	$tree->DeleteChildren($root);

	# Searchs below the root path and caches it
	@{ $self->{CACHED}->{$project_dir}->{Data} } = $self->_search($root);

	# Caches the searched word to the project
	$self->{CACHED}->{$project_dir}->{value} = $value;

	# Expands all the folders to the files matched
	$tree->ExpandAll;

	# Shows the Cancel button
	$self->ShowCancelButton(1);

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
