package Padre::Wx::MainWindow;

use 5.008;
use strict;
use warnings;

# This is somewhat disturbing but necessary to prevent
# Test::Compile from breaking. The compile tests run
# perl -v lib/Padre/Wx/MainWindow.pm which first compiles
# the module as a script (i.e. no %INC entry created)
# and then again when Padre::Wx::MainWindow is required
# from another module down the dependency chain.
# This used to break with subroutine redefinitions.
# So to prevent this, we force the creating of the correct
# %INC entry when the file is first compiled. -- Steffen
# TODO - Test::Compile is clearly a piece of shit, someone
#        write a better and properly-crossplatform one. -- Adam K
BEGIN {
	$INC{"Padre/Wx/MainWindow.pm"} ||= __FILE__;
}

use FindBin;
use Cwd                       ();
use Carp                      ();
use Data::Dumper              ();
use File::Spec                ();
use File::Basename            ();
use List::Util                ();
use Scalar::Util              ();
use Params::Util              ();
use Padre::Util               ();
use Padre::Locale             ();
use Padre::Wx                 ();
use Padre::Wx::Editor         ();
use Padre::Wx::ToolBar        ();
use Padre::Wx::Output         ();
use Padre::Document           ();
use Padre::Documents          ();
use Padre::Wx::FileDropTarget ();

our $VERSION = '0.20';
our @ISA     = 'Wx::Frame';

my $default_dir = Cwd::cwd();

use constant SECONDS => 1000;





#####################################################################
# Constructor and Accessors

use Class::XSAccessor
	getters => {
		menu           => 'menu',
		manager        => 'manager',
		no_refresh     => '_no_refresh',
		syntax_checker => 'syntax_checker',
	};

sub new {
	my $class  = shift;
	my $config = Padre->ide->config;

	Wx::InitAllImageHandlers();
	Wx::Log::SetActiveTarget( Wx::LogStderr->new );

	# Determine the initial frame style
	my $wx_frame_style = Wx::wxDEFAULT_FRAME_STYLE;
	if ( $config->{host}->{main_maximized} ) {
		$wx_frame_style |= Wx::wxMAXIMIZE;
	}

	# Determine the window title
	my $title = "Padre $Padre::VERSION ";
	if ( $0 =~ /padre$/ ) {
		my $dir = $0;
		$dir =~ s/padre$//;
		if ( -d "$dir.svn" ) {
			$title .= Wx::gettext('(running from SVN checkout)');
		}
	}

	# Create the underlying Wx frame
	my $self = $class->SUPER::new(
		undef,
		-1,
		$title,
		[
		    $config->{host}->{main_left},
		    $config->{host}->{main_top},
		],
		[
		    $config->{host}->{main_width},
		    $config->{host}->{main_height},
		],
		$wx_frame_style,
	);

	# Set the locale
	$self->{locale} = Padre::Locale::object();

	$self->SetDropTarget(
		Padre::Wx::FileDropTarget->new($self)
	);

	$self->{manager} = Wx::AuiManager->new;
	$self->{manager}->SetManagedWindow($self);
	$self->{_methods} = [];

	# do NOT use hints other than Rectangle or the app will crash on Linux/GTK
	my $flags = $self->{manager}->GetFlags;
	$flags &= ~Wx::wxAUI_MGR_TRANSPARENT_HINT;
	$flags &= ~Wx::wxAUI_MGR_VENETIAN_BLINDS_HINT;
	$self->{manager}->SetFlags( $flags ^ Wx::wxAUI_MGR_RECTANGLE_HINT );

	# Add some additional attribute slots
	$self->{marker} = {};

	$self->{page_history} = [];

	# create basic window components
	$self->create_main_components;

	$self->create_editor_pane;

	$self->create_side_pane;

	$self->create_bottom_pane;

	# Create the syntax checker and sidebar for syntax check messages
	# create it AFTER the bottom pane!
	$self->{syntax_checker} = Padre::Wx::SyntaxChecker->new($self);

	# on close pane
	Wx::Event::EVT_AUI_PANE_CLOSE(
		$self,
		sub {
			$_[0]->on_close_pane($_[1]);
		},
	);

	# Special Key Handling
	Wx::Event::EVT_KEY_UP( $self, sub {
		my ($self, $event) = @_;
		my $mod  = $event->GetModifiers || 0;
		my $code = $event->GetKeyCode;
		
		# remove the bit ( Wx::wxMOD_META) set by Num Lock being pressed on Linux
		$mod = $mod & (Wx::wxMOD_ALT() + Wx::wxMOD_CMD() + Wx::wxMOD_SHIFT());
		if ( $mod == Wx::wxMOD_CMD ) { # Ctrl
			# Ctrl-TAB  #TODO it is already in the menu
			$self->on_next_pane if $code == Wx::WXK_TAB;
		} elsif ( $mod == Wx::wxMOD_CMD() + Wx::wxMOD_SHIFT()) { # Ctrl-Shift
			# Ctrl-Shift-TAB #TODO it is already in the menu
			$self->on_prev_pane if $code == Wx::WXK_TAB;
		}
		$event->Skip();
		return;
	} );

	# remember the last time we show them or not
	# TODO do we need this, given that we have self->manager->LoadPerspective below?
	unless ( $config->{main_output_panel} ) {
		$self->{gui}->{output_panel}->Hide;
	}
	unless ( $config->{main_subs_panel} ) {
		$self->{gui}->{subs_panel}->Hide;
	}
	$self->check_pane_needed('sidepane');
	$self->manager->Update;

	# Deal with someone closing the window
	Wx::Event::EVT_CLOSE(           $self,     \&on_close_window     );
	Wx::Event::EVT_STC_UPDATEUI(    $self, -1, \&on_stc_update_ui    );
	Wx::Event::EVT_STC_CHANGE(      $self, -1, \&on_stc_change       );
	Wx::Event::EVT_STC_STYLENEEDED( $self, -1, \&on_stc_style_needed );
	Wx::Event::EVT_STC_CHARADDED(   $self, -1, \&on_stc_char_added   );
	Wx::Event::EVT_STC_DWELLSTART(  $self, -1, \&on_stc_dwell_start  );

	# As ugly as the WxPerl icon is, the new file toolbar image is uglier
	$self->SetIcon( Wx::GetWxPerlIcon() );

	# we need an event immediately after the window opened
	# (we had an issue that if the default of main_statusbar was false it did not show
	# the status bar which is ok, but then when we selected the menu to show it, it showed
	# at the top)
	# TODO: there might be better ways to fix that issue...
	my $timer = Wx::Timer->new( $self, Padre::Wx::id_POST_INIT_TIMER );
	Wx::Event::EVT_TIMER(
		$self,
		Padre::Wx::id_POST_INIT_TIMER,
		sub {
			$_[0]->timer_post_init;
		},
	);
	$timer->Start( 1, 1 );

	return $self;
}

sub create_main_components {
	my $self = shift;

	# Create the menu bar
	delete $self->{menu} if defined $self->{menu};
	$self->{menu} = Padre::Wx::Menu->new($self);
	$self->SetMenuBar( $self->menu->wx );

	# Create the tool bar
	$self->SetToolBar(
		Padre::Wx::ToolBar->new($self)
	);
	$self->GetToolBar->Realize;

	# Create the status bar
	unless ( defined $self->{gui}->{statusbar} ) {
		$self->{gui}->{statusbar} = $self->CreateStatusBar( 1, Wx::wxST_SIZEGRIP|Wx::wxFULL_REPAINT_ON_RESIZE );
		$self->{gui}->{statusbar}->SetFieldsCount(4);
		$self->{gui}->{statusbar}->SetStatusWidths(-1, 100, 50, 100);
	}

	return;
}


sub create_editor_pane {
	my $self = shift;

	# Create the main notebook for the documents
	$self->{gui}->{notebook} = Wx::AuiNotebook->new(
		$self,
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxAUI_NB_DEFAULT_STYLE | Wx::wxAUI_NB_WINDOWLIST_BUTTON,
	);

	$self->manager->AddPane(
		$self->nb,
		Wx::AuiPaneInfo->new->Name('editorpane')
			->CenterPane->Resizable->PaneBorder->Dockable
			->Caption( Wx::gettext('Files') )->Position(1)
	);

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CHANGED(
		$self,
		$self->{gui}->{notebook},
		\&on_notebook_page_changed,
	);

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CLOSE(
		$self,
		$self->nb,
		\&on_close,
	);

#	Wx::Event::EVT_DESTROY(
#	   $self,
#	   $self->nb,
#	   sub {print "destroy @_\n"; },
#	);

	return;
}

sub create_side_pane {
	my $self = shift;

	$self->{gui}->{sidepane} = Wx::Notebook->new(
		$self,
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::Size->new(300, 350), # used when pane is floated
		Wx::wxNB_TOP
	);

	# Create the right-hand sidebar
	$self->{gui}->{subs_panel} = Wx::ListCtrl->new(
		$self->{gui}->{sidepane},
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_SINGLE_SEL | Wx::wxLC_NO_HEADER | Wx::wxLC_REPORT
	);

	Wx::Event::EVT_KILL_FOCUS( $self->{gui}->{subs_panel}, \&on_subs_panel_left );

	# find-as-you-type in functions tab
	# TODO: should the whole subs_panel stuff be in its own class?
	Wx::Event::EVT_CHAR( $self->{gui}->{subs_panel}, sub {
		my ($self, $event) = @_;
		my $mod  = $event->GetModifiers || 0;
		my $code = $event->GetKeyCode;
		
		# remove the bit ( Wx::wxMOD_META) set by Num Lock being pressed on Linux
		$mod = $mod & (Wx::wxMOD_ALT() + Wx::wxMOD_CMD() + Wx::wxMOD_SHIFT()); # TODO: This is cargo-cult

		if (!$mod) {
			if ($code <= 255 and $code > 0 and chr($code) =~ /^[\w_:-]$/) { # TODO is there a better way? use ==?
				$code = 95 if $code == 45; # transform - => _ for convenience
				$self->{function_find_string} .= chr($code);
				# this does a partial match starting at the beginning of the function name
				my $pos = $self->FindItem(0, $self->{function_find_string}, 1);
				if (defined $pos) {
					$self->SetItemState($pos, Wx::wxLIST_STATE_SELECTED, Wx::wxLIST_STATE_SELECTED);
				}
			}
			else {
				# reset the find string
				$self->{function_find_string} = undef;
			}
		}

		$event->Skip(1);
		return;
	} );

	$self->{gui}->{sidepane}->AddPage( $self->{gui}->{subs_panel}, Wx::gettext("Subs"), 1 );

	$self->manager->AddPane(
		$self->{gui}->{sidepane},
		Wx::AuiPaneInfo->new->Name('sidepane')
			->CenterPane->Resizable(1)->PaneBorder(0)->Movable(1)
			->CaptionVisible(1)->CloseButton(1)->DestroyOnClose(0)
			->MaximizeButton(0)->Floatable(1)->Dockable(1)
			->Caption( Wx::gettext("Workspace View") )->Position(3)->Right->Layer(3)
	);

	$self->{gui}->{subs_panel}->InsertColumn(0, Wx::gettext('Methods'));
	$self->{gui}->{subs_panel}->SetColumnWidth(0, Wx::wxLIST_AUTOSIZE);

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self,
		$self->{gui}->{subs_panel},
		\&on_function_selected,
	);

	return;
}

sub create_bottom_pane {
	my $self = shift;

	$self->{gui}->{bottompane} = Wx::Notebook->new(
		$self,
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::Size->new(350, 300), # used when pane is floated
		Wx::wxNB_TOP
	);

	# Create the bottom-of-screen output textarea
	$self->{gui}->{output_panel} = Padre::Wx::Output->new(
		$self->{gui}->{bottompane}
	);

	$self->{gui}->{bottompane}->InsertPage( 0, $self->{gui}->{output_panel}, Wx::gettext("Output"), 1 );

	$self->manager->AddPane(
		$self->{gui}->{bottompane},
		Wx::AuiPaneInfo->new->Name('bottompane')
			->CenterPane->Resizable(1)->PaneBorder(0)->Movable(1)
			->CaptionVisible(1)->CloseButton(1)->DestroyOnClose(0)
			->MaximizeButton(1)->Floatable(1)->Dockable(1)
			->Caption( Wx::gettext("Output View") )->Position(2)->Bottom->Layer(4)
	);

	return;
}


# Load any default files
sub load_files {
	my $self   = shift;
	my $config = Padre->ide->config;
	my $files  = Padre->inst->{ARGV};
	if ( Params::Util::_ARRAY($files) ) {
		$self->setup_editors( @$files );
	} elsif ( $config->{main_startup} eq 'new' ) {
		$self->setup_editors();
	} elsif ( $config->{main_startup} eq 'nothing' ) {
		# nothing
	} elsif ( $config->{main_startup} eq 'last' ) {
		if ( $config->{host}->{main_files} ) {
			$self->Freeze;
			my @main_files     = @{$config->{host}->{main_files}};
			my @main_files_pos = @{$config->{host}->{main_files_pos}};
			foreach my $i ( 0 .. $#main_files ) {
				my $file = $main_files[$i];
				my $id   = $self->setup_editor($file);
				if ( $id and $main_files_pos[$i] ) {
					my $doc  = Padre::Documents->by_id($id);
					$doc->editor->GotoPos( $main_files_pos[$i] );
				}
			}
			if ( $config->{host}->{main_file} ) {
				my $id = $self->find_editor_of_file( $config->{host}->{main_file} );
				$self->on_nth_pane($id) if (defined $id);
			}
			$self->Thaw;
		}
	} else {
		# should never happen
	}
	return;
}

sub timer_post_init { 
	my $self = shift;

	my $output = $self->menu->view->{view_output}->IsChecked;
	# Show the output window and then hide it if necessary
	# in order to avoide some weird visual artifacts (empty square at
	# top left part of the whole application)
	# TODO maybe some users want to make sure the output window is always
	# off at startup.
	$self->show_output(1);
	$self->show_output($output) unless $output;

	# Do an initial Show/paint of the complete-looking main window
	# without any files loaded. Then immediately Freeze so that the
	# loading of the files is done in a single render pass.
	$self->Show(1);
	$self->Freeze;

	# Load all files and refresh the application so that it
	# represents the loaded state.
	$self->load_files;
	$self->on_toggle_status_bar;
	Padre->ide->plugin_manager->enable_editors_for_all;
	$self->refresh;

	if ( $self->menu->view->{view_show_syntaxcheck}->IsChecked ) {
		$self->syntax_checker->enable(1);
	}

	# Now we are fully loaded and can paint continuously
	$self->Thaw;

	# Check for new plugins and alert the user to them
	my $plugins = Padre->ide->plugin_manager->alert_new;

	# Start the change detection timer
	my $timer = Wx::Timer->new( $self, Padre::Wx::id_FILECHK_TIMER );
	Wx::Event::EVT_TIMER( $self,
		Padre::Wx::id_FILECHK_TIMER,
		sub {
			$_[0]->timer_check_overwrite;
		},
	);
	$timer->Start( 5 * SECONDS, 0 );

	return;
}





#####################################################################
# Window Methods

sub window_width {
	($_[0]->GetSizeWH)[0];
}

sub window_height {
	($_[0]->GetSizeWH)[1];
}

sub window_left {
	($_[0]->GetPositionXY)[0];
}

sub window_top {
	($_[0]->GetPositionXY)[1];
}





#####################################################################
# Refresh Methods

sub refresh {
	my $self = shift;
	return if $self->no_refresh;
	$self->Freeze;

	# Freeze during the subtle parts of the refresh
	$self->refresh_menu;
	$self->refresh_toolbar;
	$self->refresh_status;
	$self->refresh_methods;
	$self->refresh_syntaxcheck;

	my $id = $self->nb->GetSelection;
	if ( defined $id and $id >= 0 ) {
		$self->nb->GetPage($id)->SetFocus;
	}

	# force update of list of opened files in window menu
	# TODO: shouldn't this be in Padre::Wx::Menu::refresh()?
	if ( defined $self->menu->{alt} ) {
		my $doc = $self->selected_document;
		foreach my $i ( 0 .. @{ $self->menu->{alt} } - 1 ) {
			my $doc = Padre::Documents->by_id($i) or return;
			my $file = $doc->filename || $self->nb->GetPageText($i);
			$self->menu->update_alt_n_menu($file, $i);
		}
	}

	$self->Thaw;
	return;
}

sub change_locale {
	my $self = shift;

	# Save the locale to the config
	Padre->ide->config->{host}->{locale} = $_[0];

	# Reset the locale
	$self->{locale} = Padre::Locale::object();

	# Refresh the interface with the new labels
	$self->create_main_components;
	$self->refresh;

	# Replace the AUI component captions
	$self->manager->GetPane('sidepane')->Caption( Wx::gettext("Subs") );
	$self->manager->GetPane('bottompane')->Caption( Wx::gettext("Output") );

	return;
}

sub refresh_syntaxcheck {
	my $self = shift;
	return if $self->no_refresh;
	return if not Padre->ide->config->{experimental};
	return if not $self->menu->view->{view_show_syntaxcheck}->IsChecked;

	Padre::Wx::SyntaxChecker::on_syntax_check_timer( $self, undef, 1 );

	return;
}

sub refresh_menu {
	my $self = shift;
	return if $self->no_refresh;
	$self->menu->refresh;
}

sub refresh_toolbar {
	my $self = shift;
	return if $self->no_refresh;
	$self->GetToolBar->refresh($self->selected_document);
}

sub refresh_status {
	my ($self) = @_;
	return if $self->no_refresh;

	my $pageid = $self->nb->GetSelection();
	if (not defined $pageid or $pageid == -1) {
		$self->SetStatusText("", $_) for (0..3);
		return;
	}
	my $editor       = $self->nb->GetPage($pageid);
	my $doc          = Padre::Documents->current or return;
	my $line         = $editor->GetCurrentLine;
	my $filename     = $doc->filename || '';
	my $newline_type = $doc->get_newline_type || Padre::Util::NEWLINE;
	my $modified     = $editor->GetModify ? '*' : ' ';

	if ($filename) {
		$self->nb->SetPageText($pageid, $modified . File::Basename::basename $filename);
	} else {
		my $text = substr($self->nb->GetPageText($pageid), 1);
		$self->nb->SetPageText($pageid, $modified . $text);
	}

	my $pos   = $editor->GetCurrentPos;
	my $start = $editor->PositionFromLine($line);
	my $char  = $pos-$start;

	$self->SetStatusText("$modified $filename",             0);

	my $charWidth = $self->{gui}->{statusbar}->GetCharWidth;
	my $mt = $doc->get_mimetype;
	my $curPos = Wx::gettext('L:') . ($line + 1) . ' ' . Wx::gettext('Ch:') . $char;

	$self->SetStatusText($mt,           1);
	$self->SetStatusText($newline_type, 2);
	$self->SetStatusText($curPos,       3);

	# since charWidth is an average we adjust the values a little
	$self->{gui}->{statusbar}->SetStatusWidths(
		-1,
		(length($mt)           - 1) * $charWidth,
		(length($newline_type) + 2) * $charWidth,
		(length($curPos)       + 1) * $charWidth
	); 

	return;
}

# TODO now on every ui chnage (move of the mouse)
# we refresh this even though that should not be
# necessary 
# can that be eliminated ?
sub refresh_methods {
	my $self = shift;
	return if $self->no_refresh;
	return unless $self->menu->view->{view_functions}->IsChecked;

	my $subs_panel = $self->{gui}->{subs_panel};

	my $doc = $self->selected_document;
	unless ( $doc ) {
		$subs_panel->DeleteAllItems;
		return;
	}

	my @methods = $doc->get_functions;
	my $config  = Padre->ide->config;
	if ($config->{editor_methods} eq 'original') {
		# that should be the one we got from get_functions
	} elsif ($config->{editor_methods} eq 'alphabetical_private_last') {
		# ~ comes after \w
		@methods = map { tr/~/_/; $_ } ## no critic
			sort
			map { tr/_/~/; $_ } ## no critic
			@methods;
	} else {
		# Alphabetical (aka 'abc')
		@methods = sort @methods;
	}

	my $new = join ';', @methods;
	my $old = join ';', @{ $self->{_methods} };
	return if $old eq $new;

	$subs_panel->DeleteAllItems;
	foreach my $method ( reverse @methods ) {
		$subs_panel->InsertStringItem(0, $method);
	}
	$subs_panel->SetColumnWidth(0, Wx::wxLIST_AUTOSIZE);
	$self->{_methods} = \@methods;

	return;
}





#####################################################################
# Introspection

sub selected_document {
	Padre::Documents->current;
}

sub nb {
	return $_[0]->{gui}->{notebook};
}

=head2 selected_editor

 my $editor = $self->selected_editor;
 my $text   = $editor->GetText;

 ... do your stuff with the $text

 $editor->SetText($text);

You can also use the following two methods to make
your editing a atomic in the Undo stack.

 $editor->BeginUndoAction;
 $editor->EndUndoAction;


=cut

sub selected_editor {
	my $nb = $_[0]->nb;
	return $nb->GetPage( $nb->GetSelection );
}

=head2 selected_filename

Returns the name filename of the current buffer.

=cut

sub selected_filename {
	my $self = shift;
	my $doc = $self->selected_document or return;
	return $doc->filename;
}

sub selected_text {
	my $self = shift;
	my $id   = $self->nb->GetSelection;
	return if $id == -1;
	return $self->selected_editor->GetSelectedText;
}

sub pageids {
	return ( 0 .. $_[0]->nb->GetPageCount - 1 );
}

sub pages {
	my $notebook = $_[0]->nb;
	return map { $notebook->GetPage($_) } $_[0]->pageids;
}





#####################################################################
# Process Execution

# probably need to be combined with run_command
sub on_run_command {
	my $main_window = shift;

	my $dialog = Padre::Wx::History::TextDialog->new(
		$main_window,
		Wx::gettext("Command line"),
		Wx::gettext("Run setup"),
		"run_command",
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $command = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $command and $command ne '' ) {
		return;
	}
	$main_window->run_command( $command );
	return;
}

sub run_command {
	my $self   = shift;
	my $cmd    = shift;

	# Disable access to the run menus
	$self->menu->run->disable;

	# Prepare the output window for the output
	$self->show_output(1);
	$self->{gui}->{output_panel}->Remove( 0, $self->{gui}->{output_panel}->GetLastPosition );

	# If this is the first time a command has been run,
	# set up the ProcessStream bindings.
	unless ( $Wx::Perl::ProcessStream::VERSION ) {
		require Wx::Perl::ProcessStream;
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDOUT(
			$self,
			sub {
				$_[1]->Skip(1);
				my $outpanel = $_[0]->{gui}->{output_panel};
				$outpanel->style_neutral;
				$outpanel->AppendText( $_[1]->GetLine . "\n" );
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDERR(
			$self,
			sub {
				$_[1]->Skip(1);
				my $outpanel = $_[0]->{gui}->{output_panel};
				$outpanel->style_bad;
				$outpanel->AppendText( $_[1]->GetLine . "\n" );
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_EXIT(
			$self,
			sub {
				$_[1]->Skip(1);
				$_[1]->GetProcess->Destroy;
				$self->menu->run->enable;
			},
		);
	}

	# Start the command
	$self->{command} = Wx::Perl::ProcessStream->OpenProcess( $cmd, 'MyName1', $self );
	unless ( $self->{command} ) {
		# Failed to start the command. Clean up.
		$self->menu->run->enable;
	}

	return;
}

# This should really be somewhere else, but can stay here for now
sub run_script {
	my $self     = shift;
	my $document = Padre::Documents->current;
	unless ( $document ) {
		return $self->error(Wx::gettext("No open document"));
	}

	# Apply the user's save-on-run policy
	# TODO: Make this code suck less
	my $config = Padre->ide->config;
	if ( $config->{run_save} eq 'same' ) {
		$self->on_save;
	} elsif ( $config->{run_save} eq 'all_files' ) {
		$self->on_save_all;
	} elsif ( $config->{run_save} eq 'all_buffer' ) {
		$self->on_save_all;
	}

	unless ( $document->can('get_command') ) {
		return $self->error(Wx::gettext("No execution mode was defined for this document"));
	}

	my $cmd = eval { $document->get_command };
	if ($@) {
		chomp $@;
		$self->error($@);
		return;
	}
	if ($cmd) {
		$self->run_command( $cmd );
	}
	return;
}

sub debug_perl {
	my $self     = shift;
	my $document = $self->selected_document;
	unless ( $document->isa('Perl::Document::Perl') ) {
		return $self->error(Wx::gettext("Not a Perl document"));
	}

	# Check the file name
	my $filename = $document->filename;
	unless ( $filename =~ /\.pl$/i ) {
		return $self->error(Wx::gettext("Only .pl files can be executed"));
	}

	# Apply the user's save-on-run policy
	# TODO: Make this code suck less
	my $config = Padre->ide->config;
	if ( $config->{run_save} eq 'same' ) {
		$self->on_save;
	} elsif ( $config->{run_save} eq 'all_files' ) {
		$self->on_save_all;
	} elsif ( $config->{run_save} eq 'all_buffer' ) {
		$self->on_save_all;
	}

	# Set up the debugger
	my $host = 'localhost';
	my $port = 12345;
	# $self->_setup_debugger($host, $port);
	local $ENV{PERLDB_OPTS} = "RemotePort=$host:$port";

	# Run with the same Perl that launched Padre
	my $perl = Padre->perl_interpreter;
	$self->run_command(qq["$perl" -d "$filename"]);
	
}





#####################################################################
# User Interaction

sub message {
	my $self    = shift;
	my $message = shift;
	my $title   = shift || Wx::gettext('Message');
	Wx::MessageBox( $message, $title, Wx::wxOK | Wx::wxCENTRE, $self );
	return;
}

sub error {
	my $self = shift;
	$self->message( shift, Wx::gettext('Error') );
}

sub find {
	my $self = shift;

	if ( not defined $self->{fast_find_panel} ) {
		require Padre::Wx::Dialog::Search;
		$self->{fast_find_panel} = Padre::Wx::Dialog::Search->new;
	}

	return $self->{fast_find_panel};
}



#####################################################################
# Event Handlers

sub on_brace_matching {
	my ($self, $event) = @_;

	my $page  = $self->selected_editor;
	my $pos1  = $page->GetCurrentPos;
	my $pos2  = $page->BraceMatch($pos1);
	if ($pos2 == -1 ) {   #Wx::wxSTC_INVALID_POSITION
		if ($pos1 > 0) {
			$pos1--;
			$pos2 = $page->BraceMatch($pos1);
		}
	}

	if ($pos2 != -1 ) {   #Wx::wxSTC_INVALID_POSITION
		#print "$pos1 $pos2\n";
		#$page->BraceHighlight($pos1, $pos2);
		#$page->SetCurrentPos($pos2);
		$page->GotoPos($pos2);
		#$page->MoveCaretInsideView;
	}
	# TODO: or any nearby position.

	return;
}


sub on_comment_out_block {
	my ($self, $event) = @_;

	my $page   = $self->selected_editor;
	my $begin  = $page->LineFromPosition($page->GetSelectionStart);
	my $end    = $page->LineFromPosition($page->GetSelectionEnd);
	my $doc    = $self->selected_document;

	my $str = $doc->comment_lines_str;
	return if not defined $str;
	$page->comment_lines($begin, $end, $str);

	return;
}

sub on_uncomment_block {
	my ($self, $event) = @_;

	my $page   = $self->selected_editor;
	my $begin  = $page->LineFromPosition($page->GetSelectionStart);
	my $end    = $page->LineFromPosition($page->GetSelectionEnd);
	my $doc    = $self->selected_document;

	my $str = $doc->comment_lines_str;
	return if not defined $str;
	$page->uncomment_lines($begin, $end, $str);

	return;
}

sub on_autocompletition {
	my $self   = shift;
	my $doc    = $self->selected_document or return;
	my ( $length, @words ) = $doc->autocomplete;
	if ( $length =~ /\D/ ) {
		Wx::MessageBox($length, Wx::gettext("Autocompletions error"), Wx::wxOK);
	}
	if ( @words ) {
		$doc->editor->AutoCompShow($length, join " ", @words);
	}
	return;
}

sub on_goto {
	my $self = shift;

	my $dialog = Wx::TextEntryDialog->new( $self, Wx::gettext("Line number:"), "", '' );
	if ($dialog->ShowModal == Wx::wxID_CANCEL) {
		return;
	}   
	my $line_number = $dialog->GetValue;
	$dialog->Destroy;
	return if not defined $line_number or $line_number !~ /^\d+$/;
	#what if it is bigger than buffer?

	my $page = $self->selected_editor;

	$line_number--;
	$page->GotoLine($line_number);

	return;
}

sub on_close_window {
	my $self   = shift;
	my $event  = shift;
	my $config = Padre->ide->config;

	# Save the list of open files
	$config->{host}->{main_files} = [
		map  { $_->filename }
		grep { $_ } 
		map  { Padre::Documents->by_id($_) }
		$self->pageids
	];
	# Save all Pos for open files
	$config->{host}->{main_files_pos} = [
		map  { $_->editor->GetCurrentPos }
		grep { $_ } 
		map  { Padre::Documents->by_id($_) }
		$self->pageids
	];
	# Save selected tab
	$config->{host}->{main_file} = $self->selected_filename;

	# Check that all files have been saved
	if ( $event->CanVeto ) {
		if ( $config->{main_startup} eq 'same' ) {
			# Save the files, but don't close
			my $saved = $self->on_save_all;
			unless ( $saved ) {
				# They cancelled at some point
				$event->Veto;
				return;
			}
		} else {
			my $closed = $self->on_close_all;
			unless ( $closed ) {
				# They cancelled at some point
				$event->Veto;
				return;
			}
		}
	}

	# Immediately hide the window so that the user
	# perceives the application as closing faster.
	# This knocks about quarter of a second off the speed
	# at which Padre appears to close.
	$self->Show(0);

	# Discover and save the state we want to memorize
	$config->{host}->{main_maximized} = $self->IsMaximized ? 1 : 0;
	unless ( $self->IsMaximized ) {
		# Don't save the maximized window size
		(
			$config->{host}->{main_width},
			$config->{host}->{main_height},
		) = $self->GetSizeWH;
		(
			$config->{host}->{main_left},
			$config->{host}->{main_top},
		) = $self->GetPositionXY;
	}

	$config->{host}->{aui_manager_layout} = $self->manager->SavePerspective;

	Padre->ide->save_config;

	# Clean up secondary windows
	if ( $self->{help} ) {
		$self->{help}->Destroy;
	}

	$event->Skip;

	return;
}

sub on_split_window {
	my ($self) = @_;

	my $editor  = $self->selected_editor;
	my $id      = $self->nb->GetSelection;
	my $title   = $self->nb->GetPageText($id);
	my $file    = $self->selected_filename;
	return if not $file;
	my $pointer = $editor->GetDocPointer();
	$editor->AddRefDocument($pointer);

	my $new_editor = Padre::Wx::Editor->new( $self->nb );
	$new_editor->{Document} = $editor->{Document};
	$new_editor->padre_setup;
	$new_editor->SetDocPointer($pointer);
	$new_editor->set_preferences;

	Padre->ide->plugin_manager->editor_enable($new_editor);

	$self->create_tab($new_editor, $file, " $title");

	return;
}

sub setup_editors {
	my ($self, @files) = @_;
	$self->Freeze;

	# If and only if there is only one current file,
	# and it is unused, close it.
	if ( $self->nb->GetPageCount == 1 ) {
		if ( Padre::Documents->current->is_unused ) {
			$self->on_close($self);
		}
	}

	if (@files) {
		foreach my $f ( @files ) {
			Padre::DB->add_recent_files($f);
			$self->setup_editor($f);
		}
	} else {
		$self->setup_editor;
	}
	$self->Thaw;
	$self->refresh;
	return;
}

sub on_new {
	$_[0]->Freeze;
	$_[0]->setup_editor;
	$_[0]->refresh;
	$_[0]->Thaw;
	return;
}

# if the current buffer is empty then fill that with the content of the
# current file otherwise open a new buffer and open the file there.
sub setup_editor {
	my ($self, $file) = @_;

	if ($file) {
		my $id = $self->find_editor_of_file($file);
		if (defined $id) {
			$self->on_nth_pane($id);
			return;
		}
	}

	local $self->{_no_refresh} = 1;

	my $config = Padre->ide->config;
	
	my $doc = Padre::Document->new(
		filename => $file,
	);
	if ($doc->errstr) {
		warn $doc->errstr;
		return;
	}

	my $editor = Padre::Wx::Editor->new( $self->nb );
	$editor->{Document} = $doc;
	$doc->set_editor( $editor );
	$editor->configure_editor($doc);
	
	Padre->ide->plugin_manager->editor_enable($editor);

	my $title = $editor->{Document}->get_title;

	$editor->set_preferences;

	if ( $config->{editor_syntaxcheck} ) {
		if ( $editor->GetMarginWidth(1) == 0 ) {
			$editor->SetMarginType(1, Wx::wxSTC_MARGIN_SYMBOL); # margin number 1 for symbols
			$editor->SetMarginWidth(1, 16);                     # set margin 1 16 px wide
		}
	}

	my $id = $self->create_tab($editor, $file, $title);

	$editor->padre_setup;

	Wx::Event::EVT_MOTION( $editor, \&Padre::Wx::Editor::on_mouse_motion );

	return $id;
}

sub create_tab {
	my ($self, $editor, $file, $title) = @_;

	$self->nb->AddPage($editor, $title, 1);
	$editor->SetFocus;

	my $id  = $self->nb->GetSelection;
	my $file_title = $file || $title;
	$self->menu->add_alt_n_menu($file_title, $id);

	$self->refresh;

	return $id;
}

# try to open in various ways
#    as full path
#    as path relative to cwd
#    as path to relative to where the current file is
# if we are in a perl file or perl environment also try if the thing might be a name
#    of a module and try to open it locally or from @INC.
sub on_open_selection {
	my ($self, $event) = @_;
	
	# get selection, ask for it if needed
	my $selection = $self->selected_text();
	if (not $selection) {
		my $dialog = Wx::TextEntryDialog->new(
			$self,
			Wx::gettext("Nothing selected. Enter what should be opened:"),
			Wx::gettext("Open selection"),
			''
		);
		return if $dialog->ShowModal == Wx::wxID_CANCEL;

		$selection = $dialog->GetValue;
		$dialog->Destroy;
		return if not defined $selection;
	}
	
	my $file;
	if (-e $selection) {
		$file = $selection;
		if (not File::Spec->file_name_is_absolute($file)) {
			$file = File::Spec->catfile(Cwd::cwd(), $file);
			# check if this is still a file?
		}
	} else {
		my $filename
			= File::Spec->catfile(
					File::Basename::dirname($self->selected_filename),
					$selection);
		if (-e $filename) {
			$file = $filename;
		}
	}
	if (not $file) { # and we are in a Perl environment
		$selection =~ s{::}{/}g;
		$selection .= ".pm";
		my $filename = File::Spec->catfile(Cwd::cwd(), $selection);
		if (-e $filename) {
			$file = $filename;
		} else {
			foreach my $path (@INC) {
				my $filename = File::Spec->catfile( $path, $selection );
				if (-e $filename) {
					$file = $filename;
					last;
				}
			}
		}
	}

	if (not $file) {
		Wx::MessageBox(sprintf(Wx::gettext("Could not find file '%s'"), $selection), Wx::gettext("Open Selection"), Wx::wxOK, $self);
		return;
	}

	$self->setup_editors($file);

	return;
}

sub on_open_all_recent_files {
	my ( $self ) = @_;
	
	my $files = Padre::DB->get_recent_files;
	$self->setup_editors( @$files );
}

sub on_open {
	my ($self, $event) = @_;

	my $current_filename = $self->selected_filename;
	if ($current_filename) {
		$default_dir = File::Basename::dirname($current_filename);
	}
	my $dialog = Wx::FileDialog->new(
		$self,
		Wx::gettext("Open file"),
		$default_dir,
		"",
		"*.*",
		Wx::wxFD_MULTIPLE,
	);
	unless ( Padre::Util::WIN32 ) {
		$dialog->SetWildcard("*");
	}
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my @filenames = $dialog->GetFilenames;
	$default_dir = $dialog->GetDirectory;

	my @files = map { File::Spec->catfile($default_dir, $_) } @filenames;
	$self->setup_editors(@files);

	return;
}

sub on_reload_file {
	my ($self) = @_;

	my $doc     = $self->selected_document or return;
	if (not $doc->reload) {
		$self->error(sprintf(Wx::gettext("Could not reload file: %s"), $doc->errstr));
	} else {
		$doc->editor->configure_editor($doc);
	}

	return;
}

# Returns true if saved.
# Returns false if cancelled.
sub on_save_as {
	my $self    = shift;
	my $doc     = $self->selected_document or return;
	my $current = $doc->filename;
	if ( defined $current ) {
		$default_dir = File::Basename::dirname($current);
	}
	while (1) {
		my $dialog = Wx::FileDialog->new(
			$self,
			Wx::gettext("Save file as..."),
			$default_dir,
			"",
			"*.*",
			Wx::wxFD_SAVE,
		);
		if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
			return 0;
		}
		my $filename = $dialog->GetFilename;
		$default_dir = $dialog->GetDirectory;
		my $path = File::Spec->catfile($default_dir, $filename);
		if ( -e $path ) {
			my $res = Wx::MessageBox(
				Wx::gettext("File already exists. Overwrite it?"),
				Wx::gettext("Exist"),
				Wx::wxYES_NO,
				$self,
			);
			if ( $res == Wx::wxYES ) {
				$doc->_set_filename($path);
				$doc->set_newline_type(Padre::Util::NEWLINE);
				last;
			}
		} else {
			$doc->_set_filename($path);
			$doc->set_newline_type(Padre::Util::NEWLINE);
			last;
		}
	}
	my $pageid = $self->nb->GetSelection;
	$self->_save_buffer($pageid);

	$doc->set_mimetype( $doc->guess_mimetype );
	$doc->editor->padre_setup;
	$doc->rebless;

	$self->refresh;

	return 1;
}

sub on_save {
	my $self = shift;

	my $doc    = $self->selected_document or return;

	if ( $doc->is_new ) {
		return $self->on_save_as;
	}
	if ( $doc->is_modified ) {
		my $pageid = $self->nb->GetSelection;
		$self->_save_buffer($pageid);
	}

	return;
}

# Returns true if all saved.
# Returns false if cancelled.
sub on_save_all {
	my $self = shift;
	foreach my $id ( $self->pageids ) {
		my $doc = Padre::Documents->by_id($id);
		$self->on_save( $doc ) or return 0;
	}
	return 1;
}

sub _save_buffer {
	my ($self, $id) = @_;

	my $page         = $self->nb->GetPage($id);
	my $doc          = Padre::Documents->by_id($id) or return;

	if ($doc->has_changed_on_disk) {
		my $ret = Wx::MessageBox(
			Wx::gettext("File changed on disk since last saved. Do you want to overwrite it?"),
			$doc->filename || Wx::gettext("File not in sync"),
			Wx::wxYES_NO|Wx::wxCENTRE,
			$self,
		);
		return if $ret != Wx::wxYES;
	}

	if (not $doc->save_file) {
		Wx::MessageBox(Wx::gettext("Could not save file: ") . $doc->errstr, Wx::gettext("Error"), Wx::wxOK, $self);
		return;
	}

	Padre::DB->add_recent_files($doc->filename);
	$page->SetSavePoint;
	$self->refresh;

	return;
}

# Returns true if closed.
# Returns false on cancel.
sub on_close {
	my ($self, $event) = @_;

	# When we get an Wx::AuiNotebookEvent from it will try to close
	# the notebook no matter what. For the other events we have to
	# close the tab manually which we do in the close() function
	# Hence here we don't allow the automatic closing of the window. 
	if ( $event and $event->isa('Wx::AuiNotebookEvent') ) {
		$event->Veto;
	}
	$self->close;
	$self->refresh;
}

sub close {
	my ($self, $id) = @_;

	$id = defined $id ? $id : $self->nb->GetSelection;
	
	return if $id == -1;
	
	my $doc = Padre::Documents->by_id($id) or return;

	local $self->{_no_refresh} = 1;
	

	if ( $doc->is_modified and not $doc->is_unused ) {
		my $ret = Wx::MessageBox(
			Wx::gettext("File changed. Do you want to save it?"),
			$doc->filename || Wx::gettext("Unsaved File"),
			Wx::wxYES_NO|Wx::wxCANCEL|Wx::wxCENTRE,
			$self,
		);
		if ( $ret == Wx::wxYES ) {
			$self->on_save( $doc );
		} elsif ( $ret == Wx::wxNO ) {
			# just close it
		} else {
			# Wx::wxCANCEL, or when clicking on [x]
			return 0;
		}
	}
	$self->nb->DeletePage($id);

	# Update the alt-n menus
	# TODO: shouldn't this be in Padre::Wx::Menu::refresh()?
	# TODO: why don't we call $self->refresh()?
	$self->menu->remove_alt_n_menu;
	foreach my $i ( 0 .. @{ $self->menu->{alt} } - 1 ) {
		my $doc = Padre::Documents->by_id($i) or return;
		my $file = $doc->filename
			|| $self->nb->GetPageText($i);
		$self->menu->update_alt_n_menu($file, $i);
	}

	return 1;
}

# Returns true if all closed.
# Returns false if cancelled.
sub on_close_all {
	my $self = shift;
	return $self->_close_all;
}

sub on_close_all_but_current {
	my $self = shift;
	return $self->_close_all( $self->nb->GetSelection );
}

sub _close_all {
	my ($self, $skip) = @_;

	$self->Freeze;
	foreach my $id ( reverse $self->pageids ) {
		next if defined $skip and $skip == $id;
		$self->close( $id ) or return 0;
	}
	$self->refresh;
	$self->Thaw;

	return 1;
}

sub on_nth_pane {
	my ($self, $id) = @_;
	my $page = $self->nb->GetPage($id);
	if ($page) {
		$self->nb->SetSelection($id);
		$self->refresh_status;
		$page->{Document}->set_indentation_style(); # TODO: encapsulation?
		return 1;
	}

	return;
}

sub on_next_pane {
	my ($self) = @_;

	my $count = $self->nb->GetPageCount;
	return if not $count;

	my $id    = $self->nb->GetSelection;
	if ($id + 1 < $count) {
		$self->on_nth_pane($id + 1);
	} else {
		$self->on_nth_pane(0);
	}
	return;
}

sub on_prev_pane {
	my ($self) = @_;
	my $count = $self->nb->GetPageCount;
	return if not $count;
	my $id    = $self->nb->GetSelection;
	if ($id) {
		$self->on_nth_pane($id - 1);
	} else {
		$self->on_nth_pane($count-1);
	}
	return;
}

sub on_diff {
	my $self = shift;
	my $doc  = Padre::Documents->current;
	return if not $doc;

	my $current = $doc->text_get;
	my $file    = $doc->filename;
	return $self->error(Wx::gettext("Cannot diff if file was never saved")) if not $file;

	require Text::Diff;
	my $diff = Text::Diff::diff($file, \$current);
	
	if ( not $diff ) {
		$diff = Wx::gettext("There are no differences\n");
	}
	$self->show_output;
	$self->{gui}->{output_panel}->clear;
	$self->{gui}->{output_panel}->AppendText($diff);
	return;
}

#
# on_full_screen()
#
# toggle full screen status.
#
sub on_full_screen {
	my ($self, $event) = @_;
	$self->ShowFullScreen( ! $self->IsFullScreen );
}

#
# on_join_lines()
#
# join current line with next one (a-la vi with Ctrl+J)
#
sub on_join_lines {
	my ($self) = @_;

	my $page = $self->selected_editor;

	# find positions
	my $pos1 = $page->GetCurrentPos;
	my $line = $page->LineFromPosition($pos1);
	my $pos2 = $page->PositionFromLine($line+1);

	# mark target & join lines
	$page->SetTargetStart($pos1);
	$page->SetTargetEnd($pos2);
	$page->LinesJoin;
}

###### preferences and toggle functions

sub zoom {
	my $self = shift;
	my $zoom = $self->selected_editor->GetZoom + shift;
	foreach my $page ( $self->pages ) {
		$page->SetZoom($zoom);
	}
}

sub on_preferences {
	my $self = shift;

	if (Padre::Wx::Dialog::Preferences->run( $self )) {
		foreach my $editor ( $self->pages ) {
			$editor->set_preferences;
		}
		$self->refresh_methods;
	}

	return;
}

sub on_toggle_line_numbers {
	my ($self, $event) = @_;

	my $config = Padre->ide->config;
	$config->{editor_linenumbers} = $event->IsChecked ? 1 : 0;

	foreach my $editor ( $self->pages ) {
		$editor->show_line_numbers( $config->{editor_linenumbers} );
	}

	return;
}

sub on_toggle_code_folding {
	my ($self, $event) = @_;

	my $config = Padre->ide->config;
	$config->{editor_codefolding} = $event->IsChecked ? 1 : 0;

	foreach my $editor ( $self->pages ) {
		$editor->show_folding( $config->{editor_codefolding} );
	}

	return;
}

sub on_toggle_current_line_background {
	my ($self, $event) = @_;

	my $config = Padre->ide->config;
	$config->{editor_currentlinebackground} = $event->IsChecked ? 1 : 0;

	foreach my $editor ( $self->pages ) {
		$editor->show_currentlinebackground( $config->{editor_currentlinebackground} ? 1 : 0 );
	}

	return;
}

sub on_toggle_syntax_check {
	my ($self, $event) = @_;

	my $config = Padre->ide->config;
	$config->{editor_syntaxcheck} = $event->IsChecked ? 1 : 0;

	$self->syntax_checker->enable( $config->{editor_syntaxcheck} ? 1 : 0 );

	$self->menu->{window_goto_syntax_check}->Enable( $config->{editor_syntaxcheck} ? 1 : 0 );

	return;
}

sub on_toggle_indentation_guide {
	my $self   = shift;

	my $config = Padre->ide->config;
	$config->{editor_indentationguides} = $self->menu->view->{view_indentation_guide}->IsChecked ? 1 : 0;

	foreach my $editor ( $self->pages ) {
		$editor->SetIndentationGuides( $config->{editor_indentationguides} );
	}

	return;
}

sub on_toggle_eol {
	my $self   = shift;

	my $config = Padre->ide->config;
	$config->{editor_eol} = $self->menu->view->{view_eol}->IsChecked ? 1 : 0;

	foreach my $editor ( $self->pages ) {
		$editor->SetViewEOL( $config->{editor_eol} );
	}

	return;
}

#
# on_toggle_whitespaces()
#
# show/hide spaces and tabs (with dots and arrows respectively).
#
sub on_toggle_whitespaces {
	my ($self) = @_;
	
	# check whether we need to show / hide spaces & tabs.
	my $config = Padre->ide->config;
	$config->{editor_whitespaces} = $self->menu->view->{view_whitespaces}->IsChecked
		? Wx::wxSTC_WS_VISIBLEALWAYS
		: Wx::wxSTC_WS_INVISIBLE;
	
	# update all open views with the new config.
	foreach my $editor ( $self->pages ) {
		$editor->SetViewWhiteSpace( $config->{editor_whitespaces} );
	}
}

sub on_word_wrap {
	my $self = shift;
	my $on   = @_ ? $_[0] ? 1 : 0 : 1;
	unless ( $on == $self->menu->view->{view_word_wrap}->IsChecked ) {
		$self->menu->view->{view_word_wrap}->Check($on);
	}
	
	my $doc = $self->selected_document;
	return unless $doc;
	
	if ( $on ) {
		$doc->editor->SetWrapMode( Wx::wxSTC_WRAP_WORD );
	} else {
		$doc->editor->SetWrapMode( Wx::wxSTC_WRAP_NONE );
	}
}

sub show_output {
	my $self = shift;
	my $on   = @_ ? $_[0] ? 1 : 0 : 1;
	unless ( $on == $self->menu->view->{view_output}->IsChecked ) {
		$self->menu->view->{view_output}->Check($on);
	}
	if ( $on ) {
		$self->{gui}->{output_panel}->Show;
		$self->{gui}->{bottompane}->SetSelection(0);
		$self->check_pane_needed('bottompane');
		$self->manager->Update;
	} else {
		$self->{gui}->{output_panel}->Hide;
		$self->check_pane_needed('bottompane');
		$self->manager->Update;
	}
	Padre->ide->config->{main_output_panel} = $on;

	return;
}

sub show_functions {
	my $self = shift;
	my $on   = ( @_ ? ($_[0] ? 1 : 0) : 1 );

	unless ( $on == $self->menu->view->{view_functions}->IsChecked ) {
		$self->menu->view->{view_functions}->Check($on);
	}
	if ( $on ) {
		$self->refresh_methods();
		$self->{gui}->{subs_panel}->Show;
		$self->{gui}->{sidepane}->SetSelection(0);
		$self->check_pane_needed('sidepane');
		$self->manager->Update;
	} else {
		$self->{gui}->{subs_panel}->Hide;
		$self->check_pane_needed('sidepane');
		$self->manager->Update;
	}
	Padre->ide->config->{main_subs_panel} = $on;

	return;
}

sub show_syntaxbar {
	my $self = shift;
	my $on   = scalar(@_) ? $_[0] ? 1 : 0 : 1;
	unless ( $self->menu->view->{view_show_syntaxcheck}->IsChecked ) {
		$self->{gui}->{syntaxcheck_panel}->Hide;
		$self->check_pane_needed('bottompane');
		$self->manager->Update;
		return;
	}
	if ( $on ) {
		$self->{gui}->{syntaxcheck_panel}->Show;
		$self->{gui}->{bottompane}->SetSelection(1);
		$self->check_pane_needed('bottompane');
		$self->manager->Update;
	}
	else {
		$self->{gui}->{syntaxcheck_panel}->Hide;
		$self->check_pane_needed('bottompane');
		$self->manager->Update;
	}
	return;
}

sub check_pane_needed {
	my ( $self, $pane ) = @_;

	my $visible = 0;
	my $cnt = $self->{gui}->{$pane}->GetPageCount - 1;

	foreach my $num ( 0 .. $cnt ) {
		my $p = undef;
		eval {
			$p = $self->{gui}->{$pane}->GetPage($num)
		};
		if ( defined($p) && $p->IsShown ) {
			$visible++;
		}
	}
	if ($visible) {
		$self->manager->GetPane($pane)->Show;
	}
	else {
		$self->manager->GetPane($pane)->Hide;
	}

	return;
}

sub on_toggle_status_bar {
	my ($self, $event) = @_;
	if ( Padre::Util::WIN32 ) {
		# Status bar always shown on Windows
		return;
	}

	# Update the configuration
	my $config = Padre->ide->config;
	$config->{main_statusbar} = $self->menu->view->{view_statusbar}->IsChecked ? 1 : 0;

	# Update the status bar
	my $status_bar = $self->GetStatusBar;
	if ( $config->{main_statusbar} ) {
		$status_bar->Show;
	} else {
		$status_bar->Hide;
	}

	return;
}

sub on_insert_from_file {
	my ( $win ) = @_;
	
	my $id  = $win->nb->GetSelection;
	return if $id == -1;
	
	# popup the window
	my $last_filename = $win->selected_filename;
	if ($last_filename) {
		$default_dir = File::Basename::dirname($last_filename);
	}
	my $dialog = Wx::FileDialog->new(
		$win, Wx::gettext('Open file'), $default_dir, '', '*.*', Wx::wxFD_OPEN,
	);
	unless ( Padre::Util::WIN32 ) {
		$dialog->SetWildcard("*");
	}
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $filename = $dialog->GetFilename;
	$default_dir = $dialog->GetDirectory;
	
	my $file = File::Spec->catfile($default_dir, $filename);
	
	my $text;
	if ( open(my $fh, '<', $file) ) {
		binmode($fh);
		local $/ = undef;
		$text = <$fh>;
	} else {
		return;
	}
	
	my $data = Wx::TextDataObject->new;
	$data->SetText($text);
	my $length = $data->GetTextLength;
	
	my $editor = $win->nb->GetPage($id);
	$editor->ReplaceSelection('');
	my $pos = $editor->GetCurrentPos;
	$editor->InsertText( $pos, $text );
	$editor->GotoPos( $pos + $length - 1 );
}

sub convert_to {
	my ($self, $newline_type) = @_;

	my $editor = $self->selected_editor;
	#$editor->SetEOLMode( $mode{$newline_type} );
	$editor->ConvertEOLs( $Padre::Document::mode{$newline_type} );

	my $id   = $self->nb->GetSelection;
	# TODO: include the changing of file type in the undo/redo actions
	# or better yet somehow fetch it from the document when it is needed.
	my $doc     = $self->selected_document or return;
	$doc->set_newline_type($newline_type);

	$self->refresh;

	return;
}

sub find_editor_of_file {
	my ($self, $file) = @_;
	foreach my $id (0 .. $self->nb->GetPageCount -1) {
	my $doc = Padre::Documents->by_id($id) or return;
		my $filename = $doc->filename;
		next if not $filename;
		return $id if $filename eq $file;
	}
	return;
}

sub run_in_padre {
	my $self = shift;
	my $doc  = $self->selected_document or return;
	my $code = $doc->text_get;
	eval $code; ## no critic
	if ( $@ ) {
		Wx::MessageBox(
			sprintf(Wx::gettext("Error: %s"), $@),
			Wx::gettext("Self error"),
			Wx::wxOK,
			$self,
		);
	}
	return;
}

sub on_function_selected {
	my ($self, $event) = @_;
	my $sub = $event->GetItem->GetText;
	return if not defined $sub;

	my $doc = $self->selected_document;
	Padre::Wx::Dialog::Find->search( search_term => $doc->get_function_regex($sub) );
	$self->selected_editor->SetFocus;
	return;
}

## STC related functions

sub on_stc_style_needed {
	my ( $self, $event ) = @_;

	my $doc = Padre::Documents->current or return;
	if ($doc->can('colorize')) {

		# workaround something that seems like a Scintilla bug
		# when the cursor is close to the end of the document
		# and there is code at the end of the document (and not comment)
		# the STC_STYLE_NEEDED event is being constantly called
		my $text = $doc->text_get;
		return if defined $doc->{_text} and $doc->{_text} eq $text;
		$doc->{_text} = $text;

		$doc->colorize;
	}

}


sub on_stc_update_ui {
	my ($self, $event) = @_;

	# avoid recursion
	return if $self->{_in_stc_update_ui};
	local $self->{_in_stc_update_ui} = 1;

	# check for brace, on current position, higlight the matching brace
	my $editor = $self->selected_editor;
	$editor->highlight_braces;
	$editor->show_calltip;

	$self->refresh_menu;
	$self->refresh_toolbar;
	$self->refresh_status;
	#$self->refresh_methods;
	#$self->refresh_syntaxcheck;
	# avoid refreshing the subs as that takes a lot of time
	# TODO maybe we should refresh it on every 20s hit or so
#	$self->refresh;

	return;
}

sub on_stc_change {
	my ($self, $event) = @_;

	return if $self->no_refresh;

	return;
}

# http://www.yellowbrain.com/stc/events.html#EVT_STC_CHARADDED
# TODO: maybe we need to check this more carefully.
sub on_stc_char_added {
	my ($self, $event) = @_;

	my $key = $event->GetKey;
	if ($key == 10) { # ENTER
		my $editor = $self->selected_editor;
		$editor->autoindent("indent");
	}
	elsif ($key == 125) { # Closing brace }
		my $editor = $self->selected_editor;
		$editor->autoindent("deindent");
	}
	return;
}

sub on_stc_dwell_start {
	my ($self, $event) = @_;

	print Data::Dumper::Dumper $event;
	my $editor = $self->selected_editor;
	print "dwell: ", $event->GetPosition, "\n";
	#$editor->show_tooltip;
	#print Wx::GetMousePosition, "\n";
	#print Wx::GetMousePositionXY, "\n";

	return;
}

sub on_close_pane {
	my ( $self, $event ) = @_;
	my $pane = $event->GetPane();

	# it's ugly, but it works
	# TODO: This needs to be fixed. Data::Dumper is damn slow and this is just... wrong.
	if ( Data::Dumper::Dumper(\$pane) eq 
	     Data::Dumper::Dumper(\$self->{gui}->{output_panel}) )
	{
		$self->menu->view->{view_output}->Check(0);
	}
	elsif ( Data::Dumper::Dumper(\$pane) eq
	        Data::Dumper::Dumper(\$self->{gui}->{subs_panel}) )
	{
		$self->menu->view->{view_functions}->Check(0);
	}
}

sub on_doc_stats {
	my ($self, $event) = @_;

	my $doc = $self->selected_document;
	if (not $doc) {
		$self->message( 'No file is open', 'Stats' );
		return;
	}

	my ( $lines, $chars_with_space, $chars_without_space, $words, $is_readonly,
		$filename, $newline_type, $encoding)
		= $doc->stats;

	my @messages = (
		sprintf(Wx::gettext("Words: %d"),                $words              ),
		sprintf(Wx::gettext("Lines: %d"),                $lines              ),
		sprintf(Wx::gettext("Chars without spaces: %d"), $chars_without_space),
		sprintf(Wx::gettext("Chars with spaces: %d"),    $chars_with_space   ),
		sprintf(Wx::gettext("Newline type: %s"),         $newline_type       ),
		sprintf(Wx::gettext("Encoding: %s"),             $encoding           ),
		defined $filename
			? sprintf(Wx::gettext("Filename: %s"),       $filename)
			: Wx::gettext("No filename"),
	);
	my $message = join $/, @messages;

	if ($is_readonly) {
		$message .= "File is read-only.\n";
	}
	
	$self->message( $message, 'Stats' );
	return;
}

sub on_tab_and_space {
	my ( $self, $type ) = @_;
	
	my $doc = $self->selected_document;
	if (not $doc) {
		$self->message( 'No file is open' );
		return;
	}

	my $title = $type eq 'Space_to_Tab' ? 'Space to Tab' : 'Tab to Space';
	
	my $dialog = Padre::Wx::History::TextDialog->new(
		$self, 'How many spaces for each tab:', $title, $type,
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $space_num = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $space_num and $space_num =~ /^\d+$/ ) {
		return;
	}
	
	my $src = $self->selected_text;
	my $code = ( $src ) ? $src : $doc->text_get;
	
	return unless ( defined $code and length($code) );
	
	my $to_space = ' ' x $space_num;
	if ( $type eq 'Space_to_Tab' ) {
		$code =~ s/$to_space/\t/isg;
	} else {
		$code =~ s/\t/$to_space/isg;
	}
	
	if ( $src ) {
		my $editor = $self->selected_editor;
		$editor->ReplaceSelection( $code );
	} else {
		$doc->text_set( $code );
	}
}

sub on_delete_ending_space {
	my ( $self ) = @_;
	
	my $doc = $self->selected_document;
	if (not $doc) {
		$self->message( 'No file is open' );
		return;
	}
	
	my $src = $self->selected_text;
	my $code = ( $src ) ? $src : $doc->text_get;
	
	# remove ending space
	$code =~ s/([^\n\S]+)$//mg;
	
	if ( $src ) {
		my $editor = $self->selected_editor;
		$editor->ReplaceSelection( $code );
	} else {
		$doc->text_set( $code );
	}
}

sub on_delete_leading_space {
	my ( $self ) = @_;
	
	my $src = $self->selected_text;
	unless ( $src ) {
		$self->message('No selection');
		return;
	}
	
	my $dialog = Padre::Wx::History::TextDialog->new(
		$self, 'How many leading spaces to delete(1 tab == 4 spaces):',
		'Delete Leading Space', 'fay_delete_leading_space',
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $space_num = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $space_num and $space_num =~ /^\d+$/ ) {
		return;
	}

	my $code = $src;
	my $spaces = ' ' x $space_num;
	my $tab_num = int($space_num/4);
	my $space_num_left = $space_num - 4 * $tab_num;
	my $tabs   = "\t" x $tab_num;
	$tabs .= '' x $space_num_left if ( $space_num_left );
	$code =~ s/^($spaces|$tabs)//mg;
	
	my $editor = $self->selected_editor;
	$editor->ReplaceSelection( $code );
}

# TODO next function
# should be in a class representing the subs panel
sub on_subs_panel_left {
	my ($self, $event) = @_;
	my $main  = Padre->ide->wx->main_window;
	if ( $main->{subs_panel_was_closed} ) {
		$main->show_functions(0);
		$main->{subs_panel_was_closed} = 0;
	}
	return;
}

#
# timer_check_overwrite()
#
# called every 5 seconds to check if file has been overwritten outside of
# padre.
#
sub timer_check_overwrite {
	my $self = shift;
	my $doc  = $self->selected_document or return;

	return unless $doc->has_changed_on_disk;
	return if     $doc->{_already_popup_file_changed};

	$doc->{_already_popup_file_changed} = 1;
	my $ret = Wx::MessageBox(
		Wx::gettext("File changed on disk since last saved. Do you want to reload it?"),
		$doc->filename || Wx::gettext("File not in sync"),
		Wx::wxYES_NO | Wx::wxCENTRE,
		$self,
	);

	if ( $ret == Wx::wxYES ) {
		unless ( $doc->reload ) {
			$self->error(sprintf(Wx::gettext("Could not reload file: %s"), $doc->errstr));
		} else {
			$doc->editor->configure_editor($doc);
		}
	} else {
		$doc->{_timestamp} = $doc->time_on_file;
	}
	$doc->{_already_popup_file_changed} = 0;

	return;
}

sub on_last_visited_pane {
	my ($self, $event) = @_;

	if (@{ $self->{page_history} } >= 2) {
		@{ $self->{page_history} }[-1, -2] = @{ $_[0]->{page_history} }[-2, -1];
		foreach my $i ($self->pageids) {
			my $editor = $_[0]->nb->GetPage($i);
			if ( Scalar::Util::refaddr($editor) eq Scalar::Util::refaddr($_[0]->{page_history}[-1]) ) {
				$self->nb->SetSelection($i);
				last;
			}
		}
		#$self->refresh;
		$self->refresh_status;
		$self->refresh_toolbar;
	}
}

sub on_notebook_page_changed {
	my $editor = $_[0]->selected_editor;
	if ($editor) {
		@{ $_[0]->{page_history} } = grep {
			Scalar::Util::refaddr($_) ne Scalar::Util::refaddr($editor)
		} @{ $_[0]->{page_history} };
		push @{ $_[0]->{page_history} }, $editor;
		$editor->{Document}->set_indentation_style(); #  update indentation in case auto-update is on; TODO: encasulation?
	}
	$_[0]->refresh;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
