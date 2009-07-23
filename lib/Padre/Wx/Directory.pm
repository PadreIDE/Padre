package Padre::Wx::Directory;

use strict;
use warnings;
use Padre::Wx      ();

our $VERSION = '0.41';
our @ISA     = 'Wx::Panel';

######################################################################
# Creates Accessor
use Class::XSAccessor accessors => {
	_sizerv             => '_sizerv',
	_sizerh             => '_sizerh',
	_searcher           => '_searcher',
	_browser            => '_browser',
	_last_project       => '_last_project',
	_current_project    => '_current_project',
};

################################################################################
# new                                                                          #
#                                                                              #
# Creates the Directory Right Panel with a Search field and the Directory      #
# Browser                                                                      #
#                                                                              #
################################################################################
sub new {
	my ( $class , $main ) = @_;

	######################################################################
	# Creates the Panel where Search Field and Directory Browser will be
	# placed
	my $self = $class->SUPER::new(	$main->right,
					-1,
					Wx::wxDefaultPosition,
					Wx::wxDefaultSize,
	);

	######################################################################
	# BoxSizer to fill all the Panel space
	$self->_sizerv( Wx::BoxSizer->new( Wx::wxVERTICAL ) );
	$self->_sizerh( Wx::BoxSizer->new( Wx::wxHORIZONTAL ) );

	######################################################################
	# Creates the Search Field and the Directory Browser
	$self->_searcher( Padre::Wx::Directory::Searcher->new($self) );
	$self->_browser( Padre::Wx::Directory::Browser->new($self) );

	######################################################################
	# Adds each component to the panel
	$self->_sizerv->Add( $self->_searcher, 0, Wx::wxALL|Wx::wxEXPAND, 0 );
	$self->_sizerv->Add( $self->_browser, 1, Wx::wxALL|Wx::wxEXPAND, 0 );
	$self->_sizerh->Add( $self->_sizerv, 1, Wx::wxALL|Wx::wxEXPAND, 0 );

	######################################################################
	# Fits panel layout
	$self->SetSizerAndFit($self->_sizerh);
	$self->_sizerh->SetSizeHints($self);

	return $self;
}

################################################################################
# right                                                                        #
#                                                                              #
# Returns the right object reference (where the Directory Browser is placed)   #
#                                                                              #
################################################################################
sub right {
	$_[0]->GetParent;
}

################################################################################
# main                                                                         #
#                                                                              #
# Returns the main object reference                                            #
#                                                                              #
################################################################################
sub main {
	$_[0]->GetGrandParent;
}

################################################################################
# current                                                                      #
#                                                                              #
#                                                                              #
################################################################################
sub current {
	Padre::Current->new( main => $_[0]->main );
}

################################################################################
# gettext_label                                                                #
#                                                                              #
# Returns the window label                                                     #
#                                                                              #
################################################################################
sub gettext_label {
	Wx::gettext('Directory');
}

################################################################################
# clear                                                                        #
#                                                                              #
# Sets the current_project to 'none', and calls Directory Searcher's and       #
# Browser clear functions                                                      #
#                                                                              #
################################################################################
sub clear {
	my $self = shift;
	unless ( $self->current->filename ) {
		$self->_searcher->clear;
		$self->_browser->clear;
		$self->_last_project(undef);
	}
	return;
}

################################################################################
# update_gui                                                                   #
#                                                                              #
# Updates the gui if needed, calling Searcher and Browser respectives          #
# update_gui function                                                          #
#                                                                              #
# Called outside Directory.pm, on directory browser focus and item dragging    #
#                                                                              #
################################################################################
sub update_gui {
	my $self    = shift;
	my $current = $self->current;
	$current->ide->wx or return;

	######################################################################
	# Finds project base
	my $filename = $current->filename or return;
	my $dir = Padre::Util::get_project_dir($filename)
		|| File::Basename::dirname($filename);

	return unless -e $dir;

	######################################################################
	# Updates the current_project to the current one
	$self->_current_project($dir);

	######################################################################
	# Calls Searcher and Browser update_gui
	$self->_browser->update_gui;
	$self->_searcher->update_gui;

	######################################################################
	# Sets the last project to the current one
	$self->_last_project($dir);
}























#########################################################################################
#########################################################################################
#########################################################################################
#########################################################################################
#########################################################################################
package Padre::Wx::Directory::Searcher;

use strict;
use warnings;
use Padre::Wx      ();

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









































#########################################################################################
#########################################################################################
#########################################################################################
#########################################################################################
#########################################################################################
package Padre::Wx::Directory::Browser;

use strict;
use warnings;
use File::Basename ();
use Params::Util qw{_INSTANCE};
use Padre::Current ();
use Padre::Util    ();
use Padre::Wx      ();

our $VERSION = '0.40';
our @ISA     = 'Wx::TreeCtrl';

use constant IS_MAC => !!( $^O eq 'darwin' );
use constant IS_WIN32 => !!( $^O =~ /^MSWin/ or $^O eq 'cygwin' );

################################################################################
# new                                                                          #
#                                                                              #
# Creates a new Directory Browser object                                       #
#                                                                              #
################################################################################
sub new {
	my $class = shift;
	my $panel  = shift;

	my $self = $class->SUPER::new(
		$panel,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_FULL_ROW_HIGHLIGHT | Wx::wxTR_HAS_BUTTONS | Wx::wxBORDER_NONE
			| Wx::wxTR_LINES_AT_ROOT
	);

	$self->{SKIP}            = { map { $_ => 1 } ( '.', '..' ) }; # files that must be skipped
	$self->{CACHED}          = {};                                #
	$self->{current_item}    = {};                                # selected item of each project

	$self->_setup_image_list;                                     # assigns a ImageList to it
	$self->_setup_events;                                         # setups its events
	$self->_setup_root;                                           # adds it a root node

	$self->SetIndent(10);                                         # Ident to sub nodes

	return $self;
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
# right                                                                        #
#                                                                              #
# Returns the right object reference (where the Directory Browser is placed)   #
#                                                                              #
################################################################################
sub right {
	$_[0]->GetGrandParent;
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
# current                                                                      #
#                                                                              #
#                                                                              #
################################################################################
sub current {
	Padre::Current->new( main => $_[0]->main );
}

################################################################################
# clear                                                                        #
#                                                                              #
# Clears root node children                                                    #
#                                                                              #
################################################################################
sub clear {
	my $self = shift;
	$self->DeleteChildren( $self->GetRootItem );
	return;
}

################################################################################
# update_gui                                                                   #
#                                                                              #
# Updates the gui if needed                                                    #
#                                                                              #
################################################################################
sub update_gui {
	my $self    = shift;
	my $parent = $self->parent;
	my $searcher = $self->parent->_searcher;
	
	######################################################################
	# Gets the last and current actived projects
	my $last_project = $parent->_last_project;
	my $current_project = $parent->_current_project;

	######################################################################
	# Updates Root node data
	$self->_update_root_data;

	######################################################################
	# Returns if Search is in use
	return if $searcher->{in_use}->{$current_project};

	######################################################################
	# Gets Root node
	my $root = $self->GetRootItem;

	######################################################################
	# If the project have changed or the project root folder updates or
	# the search is not in use anymore (was just used)
	if ( (defined($current_project) and (not defined($last_project) or $last_project ne $current_project ) ) or $self->_updated_dir($current_project) or $searcher->{just_used}->{$current_project} ) {
		$self->_list_dir($root);
		delete $searcher->{just_used}->{$current_project};
	}
	
	######################################################################
	# Checks expanded sub folders and its content recursively
	_update_subdirs( $self, $root );
}

################################################################################
# _update_root_data                                                            #
#                                                                              #
# Updates root nodes data to the current project                               #
#                                                                              #
# Called when turned beteween projects                                         #
#                                                                              #
################################################################################
sub _update_root_data {
	my $self = shift;
	
	######################################################################
	# Splits the path to get the Root folder name and its path
	my ( $volume, $path, $name ) = File::Spec->splitpath( $self->parent->_current_project );

	######################################################################
	# Updates Root node data
	my $root_data = $self->GetPlData( $self->GetRootItem );
	$root_data->{dir}  = $volume . $path;
	$root_data->{name} = $name;
}

################################################################################
# _list_dir                                                                    #
#                                                                              #
# Updates a node's content                                                     #
#                                                                              #
# Called only if project directory changes or show/hide hidden files is        #
# requested                                                                    #
#                                                                              #
################################################################################
sub _list_dir {
	my ( $self, $node ) = @_;
	my $node_data = $self->GetPlData($node);
	my $path      = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	my $cached    = \%{ $self->{CACHED}->{$path} };

	######################################################################
	# Read folder's content and cache if it had changed or isn't cached
	if ( $self->_updated_dir($path) ) {

		######################################################################
		# Open the folder and sort its content by name and type
		opendir( my $dh, $path ) or return;
		my @items =
			sort { ( -d File::Spec->catfile( $path, $b ) ? 1 : 0 ) <=> ( -d File::Spec->catfile( $path, $a ) ? 1 : 0 ) }
			sort { lc($a) cmp lc($b) } grep { not $self->{SKIP}->{$_} } readdir $dh;
		closedir $dh;

		######################################################################
		# For each item, creates its CACHE data
		@{ $cached->{Data} } =
			map { { name => $_, dir => $path, type => ( -d File::Spec->catfile( $path, $_ ) ? 'folder' : 'package' ) } }
			@items;
		$cached->{Change} = ( stat $path )[10];
	}
	my @data = @{ $cached->{Data} };

	######################################################################
	# Shows / hides hidden files
	unless ( $cached->{ShowHidden} ) {

		# TODO Test if this Windows solutions works
		if (IS_WIN32) {
			require Win32::File;
			my $attribs;
			@data = grep {
				Win32::File::GetAttributes( File::Spec->catfile( $_->{dir}, $_->{name} ), $attribs )
					and !( $attribs & 2 )
			} @{ $cached->{Data} };
		} else {
			@data = grep { $_->{name} !~ /^\./ } @{ $cached->{Data} };
		}
	}

	######################################################################
	# Delete node children and populates it again
	$self->DeleteChildren($node);
	foreach my $each (@data) {
		my $new_elem = $self->AppendItem(
			$node,
			$each->{name},
			-1, -1,
			Wx::TreeItemData->new( { dir => $each->{dir}, name => $each->{name}, type => $each->{type} } )
		);
		$self->SetItemHasChildren( $new_elem, 1 ) if $each->{type} eq 'folder';
		$self->SetItemImage( $new_elem, $self->{file_types}->{ $each->{type} }, Wx::wxTreeItemIcon_Normal );
	}
}

################################################################################
# _updated_dir                                                                 #
#                                                                              #
# Returns 1 if the directory has changed or is not cached and 0 if it's still  #
# the same                                                                     #
#                                                                              #
################################################################################
sub _updated_dir {
	my $self   = shift;
	my $dir    = shift;
	my $cached = $self->{CACHED}->{$dir};

	if ( not defined($cached) or !$cached->{Data} or !$cached->{Change} or ( stat $dir )[10] != $cached->{Change} or $self->parent->_searcher->{just_used}->{$dir} ) {
		return 1;
	}
	return 0;
}

################################################################################
# _update_subdirs                                                              #
#                                                                              #
# Runs thought a directory content recursively looking if each EXPANDED item   #
# has changed and updates it                                                   #
#                                                                              #
################################################################################
sub _update_subdirs {
	my ( $self, $root ) = @_;
	my $parent = $self->parent;
	my $project = $parent->_current_project;

	my $cookie;
	######################################################################
	# Loops thought the node's total children
	for my $item ( 1 .. $self->GetChildrenCount($root) ) {

		( my $node, $cookie ) = $item == 1 ? $self->GetFirstChild($root) : $self->GetNextChild( $root, $cookie );
		my $node_data = $self->GetPlData($node);
		my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

		######################################################################
		# If the item (folder) was expanded, then expands its node and updates
		# its content recursively
		if ( defined $self->{CACHED}->{$project}->{Expanded}->{$path} ) {

			######################################################################
			# Expands the folder node
			$self->Expand($node);

			######################################################################
			# Updates the folder node if its content has any change
			$self->_list_dir($node) if $self->_updated_dir($path);

			######################################################################
			# Runs thought its content
			_update_subdirs( $self, $node );
		}

		######################################################################
		# If the item was the last selected item, selects and scrolls to it
		if ( defined $self->{current_item}->{$project} and $self->{current_item}->{$project} eq $path ) {
			$self->SelectItem($node);
			$self->ScrollTo($node);
		}
	}
}

################################################################################
# _removes_double_dot                                                          #
#                                                                              #
# Removes '..' and its previous directories                                    #
#                                                                              #
################################################################################
sub _removes_double_dot {
	my ( $self, $file ) = @_;
	my @dirs = File::Spec->splitdir($file);
	for ( my $i = 0; $i < @dirs; $i++ ) {
		splice @dirs, $i - 1, 2 if $i > 0 and $dirs[$i] eq "..";
	}
	return File::Spec->catfile(@dirs);
}

################################################################################
# _rename_or_move                                                              #
#                                                                              #
# Tries to rename a file and if success returns 1 or if fails shows a          #
# MessageBox with the reason and returns 0                                     #
#                                                                              #
################################################################################
sub _rename_or_move {
	my $self     = shift;
	my $old_file = $self->_removes_double_dot(shift);
	my $new_file = $self->_removes_double_dot(shift);

	######################################################################
	# Renames/moves the old file name to the new file name
	if ( rename $old_file, $new_file ) {

		######################################################################
		# Sets the new file to be selected
		my $project = $self->parent->_current_project;
		$self->{current_item}->{$project} = $new_file;

		######################################################################
		# Expands the node's parent (one level expand)
		my $cached = $self->{CACHED};
		$cached->{$project}->{Expanded}->{ File::Basename::dirname($new_file) } = 1;

		######################################################################
		# If the old file was expanded, keeps the new one expanded
		if ( defined $cached->{$project}->{Expanded}->{$old_file} ) {
			$cached->{$project}->{Expanded}->{$new_file} = 1;
			delete $cached->{$project}->{Expanded}->{$old_file};
		}

		######################################################################
		# Finds which is the OS separator character
		my $separator = File::Spec->catfile( $old_file, 'temp' );
		$separator =~ s/^$old_file(.?)temp$/$1/;

		######################################################################
		# Moves all cached data of the node and above it to the new path
		map {
			$cached->{ $new_file . ( defined $1 ? $1 : '' ) } = $cached->{$_}, delete $cached->{$_}
				if $_ =~ /^$old_file($separator.+?)?$/
		} keys %$cached;
		
		######################################################################
		# Returns success
		return 1;
	} else {
		######################################################################
		# Popups the error message and returns fail
		my $error_msg = $!;
		Wx::MessageBox( $error_msg, Wx::gettext('Error'), Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR );
		return 0;
	}
}

################################################################################
#                                                                              #
#                                                                              #
#                                                                              #
#                               SETUP FUNCTIONS                                #
#                                                                              #
#              Runned only when a new Directory object is created              #
#                                                                              #
#                                                                              #
#                                                                              #
################################################################################

################################################################################
# _setup_image_list                                                            #
#                                                                              #
# Assigns a ImageList object to the Directory Tree                             #
#                                                                              #
################################################################################
sub _setup_image_list {
	my $self = shift;

	######################################################################
	# File type and its icon
	my %file_types = (
		folder  => 'wxART_FOLDER',
		package => 'wxART_NORMAL_FILE',
	);

	######################################################################
	# Creates a new ImageList object
	my $image_list = Wx::ImageList->new( 16, 16 );

	######################################################################
	# Adds each type and its icon to the ImageList object
	for my $type ( keys %file_types ) {
		$self->{file_types}->{$type} = $image_list->Add( Wx::ArtProvider::GetBitmap( $file_types{$type}, 'wxART_OTHER_C', [ 16, 16 ] ) );
	}

	$self->AssignImageList($image_list);
}

################################################################################
# _setup_events                                                                #
#                                                                              #
# Setups the Directory Browser Events and the respective action                #
#                                                                              #
################################################################################
sub _setup_events {
	my $self = shift;
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self, $self,
		\&_on_tree_item_activated
	);

	Wx::Event::EVT_SET_FOCUS(
		$self,
		\&_on_focus
	);

	Wx::Event::EVT_TREE_ITEM_MENU(
		$self, $self,
		\&_on_tree_item_menu,
	);

	Wx::Event::EVT_TREE_SEL_CHANGED(
		$self, $self,
		\&_on_tree_sel_changed,
	);

	Wx::Event::EVT_TREE_ITEM_EXPANDING(
		$self, $self,
		\&_on_tree_item_expanding,
	);

	Wx::Event::EVT_TREE_ITEM_COLLAPSING(
		$self, $self,
		\&_on_tree_item_collapsing,
	);

	Wx::Event::EVT_TREE_END_LABEL_EDIT(
		$self, $self,
		\&_on_tree_end_label_edit,
	);

	Wx::Event::EVT_TREE_BEGIN_DRAG(
		$self, $self,
		\&_on_tree_begin_drag,
	);

	Wx::Event::EVT_TREE_END_DRAG(
		$self, $self,
		\&_on_tree_end_drag,
	);
}

################################################################################
# _setup_root                                                                  #
#                                                                              #
# Adds a root node to the directory tree                                       #
#                                                                              #
################################################################################
sub _setup_root {
	shift->AddRoot(
		Wx::gettext('Directory'),
		-1, -1,
		Wx::TreeItemData->new(
			{	dir  => '',
				name => '',
				type => 'folder',
			}
		)
	);
}

################################################################################
#                                                                              #
#                                                                              #
#                                                                              #
#                          DIRECTORY BROWSER EVENTS                            #
#                                                                              #
#                Executed when an pre estabilished event occurs                #
#                                                                              #
#                                                                              #
#                                                                              #
################################################################################

################################################################################
# _on_focus                                                                    #
#                                                                              #
# Action that must be executaded when the Directory Browser receives focus     #
#                                                                              #
################################################################################
sub _on_focus {
	my ( $self, $event ) = @_;
	my $main = $self->main;
	$self->update_gui if $main->has_directory;
}

################################################################################
# _on_tree_item_activated                                                      #
#                                                                              #
# Action that must be executaded when a item is activated                      #
#                                                                              #
# Called when the item is actived                                              #
#                                                                              #
################################################################################
sub _on_tree_item_activated {
	my ( $self, $event ) = @_;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	######################################################################
	# If its a folder, expands/collapses it and returns
	if ( $node_data->{type} eq "folder" ) {
		$self->Toggle($node);
		return;
	}

	######################################################################
	# Returns if the selected FILE have no path
	my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	return if not defined $path;

	######################################################################
	# Opens the selected file
	my $main = $self->main;
	if ( my $id = $main->find_editor_of_file($path) ) {
		my $page = $main->notebook->GetPage($id);
		$page->SetFocus;
	} else {
		$main->setup_editors($path);
	}
	return;
}

################################################################################
# _on_tree_end_label_edit                                                      #
#                                                                              #
# Verifies if the new file name already exists and prompt if it does or rename #
# the file if don't                                                            #
#                                                                              #
# Called when a item label is edited                                           #
#                                                                              #
################################################################################
sub _on_tree_end_label_edit {
	my ( $self, $event ) = @_;

	######################################################################
	# Returns if no label is typed
	return unless $event->GetLabel();

	######################################################################
	# Node old and new names and paths
	my $node_data = $self->GetPlData( $event->GetItem );
	my $old_file  = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	my $new_file  = File::Spec->catfile( $node_data->{dir}, $event->GetLabel() );
	my $new_label = ( File::Spec->splitpath($new_file) )[2];

	#########################################################################
	# Loops while already exists a file with the new label name
	while ( -e $new_file ) {

		######################################################################
		# Prompts the user asking for a new name for the file
		my $prompt = Wx::TextEntryDialog->new(
			$self,
			Wx::gettext('Please, choose a different name.'),
			Wx::gettext('File already exists'),
			$new_label,
		);

		######################################################################
		# If Cancel button pressed, ignores changes and returns
		if ( $prompt->ShowModal == Wx::wxID_CANCEL ) {
			$event->Veto();
			return;
		}

		######################################################################
		# Reads the new file name and generates its complete path
		$new_file = File::Spec->catfile( $node_data->{dir}, $prompt->GetValue );
		$new_label = ( File::Spec->splitpath($new_file) )[2];
		$prompt->Destroy;
	}

	######################################################################
	# Ignores changes if the renaming have no success
	$event->Veto() unless $self->_rename_or_move( $old_file, $new_file );
	return;
}

################################################################################
# _on_tree_sel_changed                                                         #
#                                                                              #
# Caches the item path as current selected item                                #
#                                                                              #
# Called when a item is selected                                               #
#                                                                              #
################################################################################
sub _on_tree_sel_changed {
	my ( $self, $event ) = @_;
	my $node_data = $self->GetPlData( $event->GetItem );

	######################################################################
	# Caches the item path
	$self->{current_item}->{ $self->parent->_current_project } = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
}

################################################################################
# _on_tree_item_expanding                                                      #
#                                                                              #
# Expands the node and loads its content                                       #
#                                                                              #
# Called when a folder is expanded                                             #
#                                                                              #
################################################################################
sub _on_tree_item_expanding {
	my ( $self, $event ) = @_;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	######################################################################
	# Returns if a search is being done (expands only the browser listing)
	return if $self->parent->_searcher->{in_use}->{$self->parent->_current_project};

	######################################################################
	# The item complete path
	my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	######################################################################
	# Cache the expanded state of the node
	$self->{CACHED}->{ $self->parent->_current_project }->{Expanded}->{$path} = 1;

	######################################################################
	# Updates the node content if it changed or has no child
	if ( $self->_updated_dir($path) or !$self->GetChildrenCount($node) ) {
		$self->_list_dir($node);
	}
}

################################################################################
# _on_tree_item_collapsing                                                     #
#                                                                              #
# Deletes nodes Expanded cache param                                           #
#                                                                              #
# Called when a folder is collapsed                                            #
#                                                                              #
################################################################################
sub _on_tree_item_collapsing {
	my ( $self, $event ) = @_;
	my $node_data = $self->GetPlData( $event->GetItem );

	######################################################################
	# Deletes cache expanded state of the node
	delete $self->{CACHED}->{ $self->parent->_current_project }->{Expanded}->{ File::Spec->catfile( $node_data->{dir}, $node_data->{name} ) };
}

################################################################################
# _on_tree_begin_drag                                                          #
#                                                                              #
# If the item is not the root node let it to be dragged                        #
#                                                                              #
# Called when a item is dragged                                                #
#                                                                              #
################################################################################
sub _on_tree_begin_drag {
	my ( $self, $event ) = @_;
	my $node = $event->GetItem;

	######################################################################
	# Only drags if it's not the Root node
	if ( $node != $self->GetRootItem ) {
		$self->{dragged_item} = $node;
		$event->Allow;
	}
}

################################################################################
# _on_tree_end_drag                                                            #
#                                                                              #
# If dragged to a different folder, tries to move (renaming) it to the new     #
# folder.                                                                      #
#                                                                              #
# Called just after the item is dragged                                        #
#                                                                              #
################################################################################
sub _on_tree_end_drag {
	my ( $self, $event ) = @_;
	my $node = $event->GetItem;

	######################################################################
	# If drops to a file, the new destination will be it's folder
	if ( $node->IsOk and !$self->ItemHasChildren($node) ) {
		$node = $self->GetItemParent($node);
	}

	######################################################################
	# Returns if the target node doesn't exists
	return if !$node->IsOk;

	######################################################################
	# Gets dragged and target nodes data
	my $new_data = $self->GetPlData($node);
	my $old_data = $self->GetPlData( $self->{dragged_item} );


	######################################################################
	# Returns if the target is the file parent
	my $from = $old_data->{dir};
	my $to = File::Spec->catfile( $new_data->{dir}, $new_data->{name} );
	return if $from eq $to;

	######################################################################
	# The file complete name (path and its name) before and after the move
	my $old_file = File::Spec->catfile( $old_data->{dir}, $old_data->{name} );
	my $new_file = File::Spec->catfile( $to, $old_data->{name} );

	######################################################################
	# Alerts if there is a file with the same name in the target
	if ( -e $new_file ) {
		Wx::MessageBox(
			Wx::gettext('Already exists a file with the same name in this directory'),
			Wx::gettext('Error'),
			Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR
		);
		return;
	}

	######################################################################
	# If the move (renaming) sucess, updates the Browser gui
	$self->update_gui if $self->_rename_or_move( $old_file, $new_file );
	return;
}

################################################################################
# _on_tree_item_menu                                                           #
#                                                                              #
# Shows up a context menu above an item with its controls                      #
# the file if don't                                                            #
#                                                                              #
# Called when a item context menu is requested                                 #
#                                                                              #
################################################################################
sub _on_tree_item_menu {
	my ( $self, $event ) = @_;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	my $menu          = Wx::Menu->new;
	my $selected_dir  = $node_data->{dir};
	my $selected_path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	######################################################################
	# Default action - same when the item is activated
	my $default =
		$menu->Append( -1, Wx::gettext( $node_data->{type} eq 'folder' ? 'Expand / Collapse' : 'Open File' ) );
	Wx::Event::EVT_MENU(
		$self, $default,
		\&_on_tree_item_activated($event)
	);
	$menu->AppendSeparator();

	######################################################################
	# Rename and/or move the item
	my $rename = $menu->Append( -1, Wx::gettext('Rename / Move') );
	Wx::Event::EVT_MENU(
		$self, $rename,
		sub {
			$self->EditLabel($node);
		},
	);

	######################################################################
	# Move item to trash
	# Note: File::Remove->trash() only works in Win and Mac

	if ( IS_WIN32 or IS_MAC ) {
		my $trash = $menu->Append( -1, Wx::gettext('Move to trash') );
		Wx::Event::EVT_MENU(
			$self, $trash,
			sub {
				eval {
					require File::Remove;
					File::Remove->trash($selected_path);
				};
				if ($@) {
					my $error_msg = $@;
					Wx::MessageBox(
						$error_msg, Wx::gettext('Error'),
						Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR
					);
				}
				return;
			},
		);
	}

	######################################################################
	# Delete item
	my $delete = $menu->Append( -1, Wx::gettext('Delete') );
	Wx::Event::EVT_MENU(
		$self, $delete,
		sub {

			my $dialog = Wx::MessageDialog->new(
				$self,
				Wx::gettext('You sure want to delete this item?') . $/ . $selected_path,
				Wx::gettext('Delete'),
				Wx::wxYES_NO | Wx::wxICON_QUESTION | Wx::wxCENTRE
			);
			return if $dialog->ShowModal == Wx::wxID_NO;

			eval {
				require File::Remove;
				File::Remove->remove($selected_path);
			};
			if ($@) {
				my $error_msg = $@;
				Wx::MessageBox(
					$error_msg, Wx::gettext('Error'),
					Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR
				);
			}
			return;
		},
	);

	######################################################################
	# ?????
	if ( defined $node_data->{type} and ( $node_data->{type} eq 'modules' or $node_data->{type} eq 'pragmata' ) ) {
		my $pod = $menu->Append( -1, Wx::gettext("Open &Documentation") );
		Wx::Event::EVT_MENU(
			$self, $pod,
			sub {

				# TODO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
				require Padre::Wx::DocBrowser;
				my $help = Padre::Wx::DocBrowser->new;
				$help->help( $node_data->{name} );
				$help->SetFocus;
				$help->Show(1);
				return;
			},
		);
	}
	$menu->AppendSeparator();

	######################################################################
	# Shows / Hides hidden files - applied to each directory
	my $hiddenFiles     = $menu->AppendCheckItem( -1, Wx::gettext('Show hidden files') );
	my $applies_to_node = $node;
	my $applies_to_path = $selected_path;
	if ( $node_data->{type} ne 'folder' ) {
		$applies_to_path = $selected_dir;
		$applies_to_node = $self->GetParent($node);
	}

	my $cached = \%{ $self->{CACHED}->{$applies_to_path} };
	my $show   = $cached->{ShowHidden};
	$hiddenFiles->Check($show);
	Wx::Event::EVT_MENU(
		$self,
		$hiddenFiles,
		sub {
			$cached->{ShowHidden} = !$show;
			$self->_list_dir($applies_to_node);
		},
	);

	######################################################################
	# Updates the directory listing
	my $reload = $menu->Append( -1, Wx::gettext('Reload') );
	Wx::Event::EVT_MENU(
		$self, $reload,
		sub {
			delete $self->{CACHED}->{ $self->GetPlData($node)->{dir} }->{Change};
		}
	);

	######################################################################
	# Pops up the context menu
	my $x = $event->GetPoint->x;
	my $y = $event->GetPoint->y;
	$self->PopupMenu( $menu, $x, $y );

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
