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
use Padre::Wx::Output         ();
use Padre::Wx::Bottom         ();
use Padre::Wx::ToolBar        ();
use Padre::Wx::Notebook       ();
use Padre::Wx::StatusBar      ();
use Padre::Wx::ErrorList      ();
use Padre::Wx::AuiManager     ();
use Padre::Wx::FileDropTarget ();
use Padre::Document           ();
use Padre::Current            qw{_CURRENT};

our $VERSION = '0.24';
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
		errorlist      => 'errorlist',
	};

# NOTE: Yes this method does get a little large, but that's fine.
#       It's better to have one bigger method that is easily
#       understandable rather than scattering tightly-related code
#       all over the place in unrelated places.
#       If you feel the need to make this smaller, try to make each
#       individual step tighter and better abstracted.
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

	# Drag and drop support
	Padre::Wx::FileDropTarget->set($self);

	# Temporary store for the function list.
	# TODO: Storing this here violates encapsulation.
	$self->{_methods} = [];

	# Temporary store for the notebook tab history
	# TODO: Storing this here (might) violate encapsulation.
	#       It should probably be in the notebook object.
	$self->{page_history} = [];

	# Set the window manager
	$self->{manager} = Padre::Wx::AuiManager->new($self);

	# Add some additional attribute slots
	$self->{marker} = {};

	# Create the menu bar
	$self->{menu} = Padre::Wx::Menubar->new($self);
	$self->SetMenuBar( $self->menu->wx );

	# Create the tool bar
	$self->SetToolBar(
		Padre::Wx::ToolBar->new($self)
	);
	$self->GetToolBar->Realize;

	# Create the status bar
	$self->{gui}->{statusbar} = Padre::Wx::StatusBar->new($self);

	# Create the main notebook for the documents
	$self->{gui}->{notebook} = Padre::Wx::Notebook->new($self);

	$self->create_side_pane;

	# Create the bottom pane
	$self->{gui}->{bottompane} = Padre::Wx::Bottom->new($self);

	# Create the output textarea
	$self->{gui}->{output_panel} = Padre::Wx::Output->new(
		$self->{gui}->{bottompane}
	);

	$self->show_output( Padre->ide->config->{main_output_panel} );

	# Create the syntax checker and sidebar for syntax check messages
	# Must be created after the bottom pane!
	$self->{syntax_checker} = Padre::Wx::SyntaxChecker->new($self);
	$self->show_syntaxbar( $self->menu->view->{show_syntaxcheck}->IsChecked );

	# Create the error list
	# Must be created after the bottom pane!
	$self->{errorlist} = Padre::Wx::ErrorList->new($self);

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

	# Deal with someone closing the window
	Wx::Event::EVT_CLOSE( $self, sub {
		shift->on_close_window(@_);
	} );

	# Scintilla Event Hooks
	Wx::Event::EVT_STC_UPDATEUI(    $self, -1, \&on_stc_update_ui    );
	Wx::Event::EVT_STC_CHANGE(      $self, -1, \&on_stc_change       );
	Wx::Event::EVT_STC_STYLENEEDED( $self, -1, \&on_stc_style_needed );
	Wx::Event::EVT_STC_CHARADDED(   $self, -1, \&on_stc_char_added   );
	Wx::Event::EVT_STC_DWELLSTART(  $self, -1, \&on_stc_dwell_start  );

	# As ugly as the WxPerl icon is, the new file toolbar image we
	# used to use was far uglier
	$self->SetIcon( Wx::GetWxPerlIcon() );

	# Load the saved pane layout from last time (if any)
	if ( defined $config->{host}->{aui_manager_layout} ) {
		$self->manager->LoadPerspective( $config->{host}->{aui_manager_layout} );
	}

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

sub create_side_pane {
	my $self = shift;

	$self->{gui}->{sidepane} = Wx::AuiNotebook->new(
		$self,
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::Size->new(300, 350), # used when pane is floated
		Wx::wxAUI_NB_SCROLL_BUTTONS
		| Wx::wxAUI_NB_TOP
		# |Wx::wxAUI_NB_TAB_EXTERNAL_MOVE crashes on Linux/GTK
	);

	# Create the right-hand sidebar
	$self->{gui}->{subs_panel} = Wx::ListCtrl->new(
		$self->{gui}->{sidepane},
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_SINGLE_SEL | Wx::wxLC_NO_HEADER | Wx::wxLC_REPORT
	);

	Wx::Event::EVT_KILL_FOCUS(
		$self->{gui}->{subs_panel},
		\&on_subs_panel_left,
	);

	# find-as-you-type in functions tab
	# TODO: should the whole subs_panel stuff be in its own class? (Yes)
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

	$self->manager->AddPane(
		$self->{gui}->{sidepane},
		Wx::AuiPaneInfo->new
			->Name('sidepane')
			->CenterPane
			->Resizable(1)
			->PaneBorder(0)
			->Movable(1)
			->CaptionVisible(1)
			->CloseButton(0)
			->DestroyOnClose(0)
			->MaximizeButton(0)
			->Floatable(1)
			->Dockable(1)
			->Caption( Wx::gettext("Workspace View") )
			->Position(3)
			->Right
			->Layer(3)
			->Hide
	);

	$self->{gui}->{subs_panel}->InsertColumn(0, Wx::gettext('Methods'));
	$self->{gui}->{subs_panel}->SetColumnWidth(0, Wx::wxLIST_AUTOSIZE);

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self,
		$self->{gui}->{subs_panel},
		\&on_function_selected,
	);

	$self->show_functions( Padre->ide->config->{main_subs_panel} );

	return;
}

# Load any default files
sub load_files {
	my $self   = shift;

	# An explicit list on the command line overrides configuration
	my $files  = Padre->inst->{ARGV};
	if ( Params::Util::_ARRAY($files) ) {
		$self->setup_editors(@$files);
		return;
	}

	# Config setting 'nothing' means startup with nothing open
	my $config  = Padre->ide->config;
	my $startup = $config->{main_startup};
	if ( $startup eq 'nothing' ) {
		return;
	}

	# Config setting 'new' means startup with a single new file open
	if ( $startup eq 'new' ) {
		$self->setup_editors;
		return;
	}

	# Config setting 'last' means startup with all the files from the
	# previous time we used Padre open (if they still exist)
	if ( $startup eq 'last' ) {
		if ( $config->{host}->{main_files} ) {
			$self->Freeze;
			my @main_files     = @{$config->{host}->{main_files}};
			my @main_files_pos = @{$config->{host}->{main_files_pos}};
			foreach my $i ( 0 .. $#main_files ) {
				my $file = $main_files[$i];
				my $id   = $self->setup_editor($file);
				if ( $id and $main_files_pos[$i] ) {
					$self->notebook->GetPage($id)->GotoPos( $main_files_pos[$i] );
				}
			}
			if ( $config->{host}->{main_file} ) {
				my $id = $self->find_editor_of_file( $config->{host}->{main_file} );
				$self->on_nth_pane($id) if defined $id;
			}
			$self->Thaw;
		}
		return;
	}

	# Configuration has an entry we don't know about
	# TODO: Once we have a warning system more useful than STDERR
	# add a warning. For now though, just do nothing and ignore.
	return;
}

sub timer_post_init { 
	my $self = shift;

	# Do an initial Show/paint of the complete-looking main window
	# without any files loaded. Then immediately Freeze so that the
	# loading of the files is done in a single render pass.
	# This gives us an optimum compromise between being PERCEIVED
	# to startup quickly, and ACTUALLY starting up quickly.
	$self->Show(1);
	$self->Freeze;

	# Load all files and refresh the application so that it
	# represents the loaded state.
	$self->load_files;
	$self->on_toggle_statusbar;
	Padre->ide->plugin_manager->enable_editors_for_all;
	if ( $self->menu->view->{show_syntaxcheck}->IsChecked ) {
		$self->syntax_checker->enable(1);
	}

	if ( $self->menu->view->{show_errorlist}->IsChecked ) {
		$self->errorlist->enable;
	}
	
	$self->refresh;
	# Now we are fully loaded and can paint continuously
	$self->Thaw;

	# Check for new plugins and alert the user to them
	Padre->ide->plugin_manager->alert_new;

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

# The term and method "refresh" is reserved for fast, blocking,
# real-time updates to the GUI. Enabling and disabling menu entries,
# updating dynamic titles and status bars, and other rapid changes.
sub refresh {
	my $self = shift;
	return if $self->no_refresh;

	# Freeze during the refresh
	$self->Freeze;

	my $current = $self->current;
	$self->refresh_menu($current);
	$self->refresh_toolbar($current);
	$self->refresh_status($current);
	$self->refresh_methods($current);

	# Fix ticket #185: Padre crash when closing files
	if ( ! $self->{no_syntax_check_refresh} ) {
		$self->refresh_syntaxcheck($current);
	}
	$self->{no_syntax_check_refresh} = 0;

	my $id = $self->notebook->GetSelection;
	if ( defined $id and $id >= 0 ) {
		$self->notebook->GetPage($id)->SetFocus;
	}

	$self->Thaw;

	return;
}

sub refresh_syntaxcheck {
	my $self = shift;
	return if $self->no_refresh;
	return if not $self->menu->view->{show_syntaxcheck}->IsChecked;
	Padre::Wx::SyntaxChecker::on_syntax_check_timer( $self, undef, 1 );
	return;
}

sub refresh_menu {
	my $self = shift;
	return if $self->no_refresh;
	$self->menu->refresh($_[0] or $self->current);
}

sub refresh_toolbar {
	my $self = shift;
	return if $self->no_refresh;
	$self->GetToolBar->refresh($_[0] or $self->current);
}

sub refresh_status {
	my $self = shift;
	return if $self->no_refresh;
	$self->GetStatusBar->refresh($_[0] or $self->current);
}

# TODO now on every ui chnage (move of the mouse)
# we refresh this even though that should not be
# necessary can that be eliminated ?
sub refresh_methods {
	my $self = shift;
	return if $self->no_refresh;
	return unless $self->menu->view->{functions}->IsChecked;

	# Flush the list if there is no active document
	my $current    = _CURRENT(@_);
	my $document   = $current->document;
	my $subs = $self->{gui}->{subs_panel};
	unless ( $document ) {
		$subs->DeleteAllItems;
		return;
	}

	my $config  = Padre->ide->config;
	my @methods = $document->get_functions;
	if ( $config->{editor_methods} eq 'original' ) {
		# That should be the one we got from get_functions
	} elsif ( $config->{editor_methods} eq 'alphabetical_private_last' ) {
		# ~ comes after \w
		@methods = map { tr/~/_/; $_ } ## no critic
			sort
			map { tr/_/~/; $_ } ## no critic
			@methods;
	} else {
		# Alphabetical (aka 'abc')
		@methods = sort @methods;
	}

	if ( scalar(@methods) == scalar(@{$self->{_methods}}) ) {
		my $new = join ';', @methods;
		my $old = join ';', @{ $self->{_methods} };
		return if $old eq $new;	
	}

	$subs->DeleteAllItems;
	foreach my $method ( reverse @methods ) {
		$subs->InsertStringItem(0, $method);
	}
	$subs->SetColumnWidth(0, Wx::wxLIST_AUTOSIZE);
	$self->{_methods} = \@methods;

	return;
}





#####################################################################
# Interface Rebuilding Methods

sub change_style {
	my $self    = shift;
	my $name    = shift;
	my $private = shift;
	Padre::Wx::Editor::data($name, $private);
	foreach my $editor ( $self->pages ) {
		$editor->padre_setup;
	}
	return;
}

sub change_locale {
	$DB::single = 1;
	my $self = shift;
	my $name = shift;
	unless ( defined $name ) {
		$name = Padre::Locale::system_rfc4646();
	}

	# Save the locale to the config
	Padre->ide->config->{host}->{locale} = $name;

	# Reset the locale
	delete $self->{locale};
	$self->{locale} = Padre::Locale::object();

	# Run the "relocale" process to update the GUI
	$self->relocale;

	# With language stuff updated, do a full refresh
	# sweep to clean everything up.
	$self->refresh;

	return;
}

# The term and method "relocale" is reserved for functionality
# intended to run when the application wishes to change locale
# (and wishes to do so without restarting).
sub relocale {
	my $self = shift;

	# The menu doesn't support relocale, replace it
	delete $self->{menu};
	$self->{menu} = Padre::Wx::Menubar->new($self);
	$self->SetMenuBar( $self->menu->wx );

	# The toolbar doesn't support relocale, replace it
	$self->SetToolBar(
		Padre::Wx::ToolBar->new($self)
	);
	$self->GetToolBar->Realize;

	# Update window manager captions
	$self->manager->relocale;

	return;
}





#####################################################################
# Introspection

sub notebook {
	return $_[0]->{gui}->{notebook};
}

=pod

=head2 current

  $self->current->document
  $self->current->editor
  $self->current->filename
  $self->current->title
  $self->current->text

Creates a L<Padre::Current> object for the main window, giving you quick
and cacheing access to the current various whatevers.

See L<Padre::Current> for more information (once we've actually written
the POD for it).

=cut

sub current {
	Padre::Current->new( main => $_[0] );
}

sub pageids {
	return ( 0 .. $_[0]->notebook->GetPageCount - 1 );
}

sub pages {
	my $notebook = $_[0]->notebook;
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
	
	# Clear the error list
	$self->errorlist->clear;

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
				
				$_[0]->errorlist->collect_data($_[1]->GetLine);
				
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_EXIT(
			$self,
			sub {
				$_[1]->Skip(1);
				$_[1]->GetProcess->Destroy;
				$self->menu->run->enable;
				$_[0]->errorlist->populate;
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
	my $document = $self->current->document;
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
		if ($document->pre_process) {
			$self->run_command( $cmd );
		} else {
			$self->error( $document->errstr );
		}
	}
	return;
}

sub debug_perl {
	my $self     = shift;
	my $document = $self->current->document;
	unless ( $document->isa('Perl::Document::Perl') ) {
		return $self->error(Wx::gettext("Not a Perl document"));
	}

	# Check the file name
	my $filename = $document->filename;
#	unless ( $filename =~ /\.pl$/i ) {
#		return $self->error(Wx::gettext("Only .pl files can be executed"));
#	}

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
	$_[0]->message( $_[1], Wx::gettext('Error') );
}

sub find {
	my $self = shift;

	unless ( defined $self->{fast_find_panel} ) {
		require Padre::Wx::Dialog::Search;
		$self->{fast_find_panel} = Padre::Wx::Dialog::Search->new;
	}

	return $self->{fast_find_panel};
}





#####################################################################
# Event Handlers

sub on_brace_matching {
	my $self  = shift;
	my $page  = $self->current->editor;
	my $pos1  = $page->GetCurrentPos;
	my $pos2  = $page->BraceMatch($pos1);
	if ( $pos2 == -1 ) {   #Wx::wxSTC_INVALID_POSITION
		if ( $pos1 > 0 ) {
			$pos1--;
			$pos2 = $page->BraceMatch($pos1);
		}
	}

	if ( $pos2 != -1 ) {   #Wx::wxSTC_INVALID_POSITION
		$page->GotoPos($pos2);
	}
	# TODO: or any nearby position.

	return;
}

sub on_comment_out_block {
	my $self     = shift;
	my $current  = $self->current;
	my $editor   = $current->editor;
	my $document = $current->document;
	my $begin    = $editor->LineFromPosition($editor->GetSelectionStart);
	my $end      = $editor->LineFromPosition($editor->GetSelectionEnd);
	my $string   = $document->comment_lines_str;
	return unless defined $string;
	$editor->comment_lines($begin, $end, $string);
	return;
}

sub on_uncomment_block {
	my $self     = shift;
	my $current  = $self->current;
	my $editor   = $current->editor;
	my $document = $current->document;
	my $begin    = $editor->LineFromPosition($editor->GetSelectionStart);
	my $end      = $editor->LineFromPosition($editor->GetSelectionEnd);
	my $string   = $document->comment_lines_str;
	return unless defined $string;
	$editor->uncomment_lines($begin, $end, $string);
	return;
}

sub on_autocompletition {
	my $self     = shift;
	my $document = $self->current->document or return;
	my ( $length, @words ) = $document->autocomplete;
	if ( $length =~ /\D/ ) {
		Wx::MessageBox(
			$length,
			Wx::gettext("Autocompletions error"),
			Wx::wxOK,
		);
	}
	if ( @words ) {
		$document->editor->AutoCompShow($length, join " ", @words);
	}
	return;
}

sub on_goto {
	my $self   = shift;
	my $dialog = Wx::TextEntryDialog->new(
		$self,
		Wx::gettext("Line number:"),
		"",
		'',
	);
	if ($dialog->ShowModal == Wx::wxID_CANCEL) {
		return;
	}   
	my $line_number = $dialog->GetValue;
	$dialog->Destroy;
	return if not defined $line_number or $line_number !~ /^\d+$/;
	#what if it is bigger than buffer?

	my $page = $self->current->editor;
	$line_number--;
	$page->goto_line_centerize($line_number);

	return;
}

sub on_close_window {
	my $self      = shift;
	my $event     = shift;
	my $padre     = Padre->ide;
	my $config    = $padre->config;
	my $notebook  = $self->notebook;
	my @documents = grep { $_ }
		map  { $_->{Document} }
		grep { $_ }
		map  { $notebook->GetPage($_) }
		$self->pageids;

	# Capture the current session, before we start the interactive
	# part of the shutdown which will mess it up. Don't save it to
	# the config yet, because we haven't committed to the shutdown
	# until we get past the interactive phase.
	my $main_file  = $self->current->filename;
	my $main_files = [ 
		map  { $_->filename }
		@documents
	];
	my $main_files_pos = [
		map  { $_->editor->GetCurrentPos }
		@documents
	];

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

	# Now it's safe to save the session
	$config->{host}->{main_file}      = $main_file;
	$config->{host}->{main_files}     = $main_files;
	$config->{host}->{main_files_pos} = $main_files_pos;

	# Save the window geometry
	$config->{host}->{aui_manager_layout} = $self->manager->SavePerspective;
	$config->{host}->{main_maximized}     = $self->IsMaximized ? 1 : 0;
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

	# Clean up our secondary windows
	if ( $self->{help} ) {
		$self->{help}->Destroy;
	}

	# Shut down all the plugins before saving the configuration
	# so that plugins have a change to save their configuration.
	$padre->plugin_manager->shutdown;

	# Write the configuration to disk
	$padre->save_config;

	$event->Skip;

	return;
}

sub on_split_window {
	my $self     = shift;
	my $current  = $self->current;
	my $notebook = $current->_notebook;
	my $editor   = $current->editor;
	my $title    = $current->title;
	my $file     = $current->filename or return;
	my $pointer  = $editor->GetDocPointer;
	$editor->AddRefDocument($pointer);

	my $new_editor = Padre::Wx::Editor->new( $self->notebook );
	$new_editor->{Document} = $editor->{Document};
	$new_editor->padre_setup;
	$new_editor->SetDocPointer($pointer);
	$new_editor->set_preferences;

	Padre->ide->plugin_manager->editor_enable($new_editor);

	$self->create_tab($new_editor, $file, " $title");

	return;
}

sub setup_editors {
	my $self  = shift;
	my @files = @_;
	$self->Freeze;

	# If and only if there is only one current file,
	# and it is unused, close it. This is a somewhat
	# subtle interface DWIM trick, but it's one that
	# clearly looks wrong when we DON'T do it.
	if ( $self->notebook->GetPageCount == 1 ) {
		if ( $self->current->document->is_unused ) {
			$self->on_close($self);
		}
	}

	if ( @files ) {
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
		warn $doc->errstr . " when trying to open '$file'";
		return;
	}

	my $editor = Padre::Wx::Editor->new( $self->notebook );
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
	$self->notebook->AddPage($editor, $title, 1);
	$editor->SetFocus;
	my $id = $self->notebook->GetSelection;
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
	my $text = $self->current->text;
	unless ( $text ) {
		my $dialog = Wx::TextEntryDialog->new(
			$self,
			Wx::gettext("Nothing selected. Enter what should be opened:"),
			Wx::gettext("Open selection"),
			''
		);
		return if $dialog->ShowModal == Wx::wxID_CANCEL;

		$text = $dialog->GetValue;
		$dialog->Destroy;
		return unless defined $text;
	}
	
	my $file;
	if ( -e $text ) {
		$file = $text;
		unless ( File::Spec->file_name_is_absolute($file) ) {
			$file = File::Spec->catfile(Cwd::cwd(), $file);
			# check if this is still a file?
		}
	} else {
		my $filename = File::Spec->catfile(
			File::Basename::dirname($self->current->filename),
			$text,
		);
		if ( -e $filename ) {
			$file = $filename;
		}
	}
	unless ( $file ) { # and we are in a Perl environment
		$text =~ s{::}{/}g;
		$text .= ".pm";
		my $filename = File::Spec->catfile(Cwd::cwd(), $text);
		if (-e $filename) {
			$file = $filename;
		} else {
			foreach my $path (@INC) {
				my $filename = File::Spec->catfile( $path, $text );
				if (-e $filename) {
					$file = $filename;
					last;
				}
			}
		}
	}

	unless ( $file ) {
		Wx::MessageBox(
			sprintf(Wx::gettext("Could not find file '%s'"), $text),
			Wx::gettext("Open Selection"),
			Wx::wxOK,
			$self,
		);
		return;
	}

	$self->setup_editors($file);

	return;
}

sub on_open_all_recent_files {
	my $files = Padre::DB->get_recent_files;
	$_[0]->setup_editors( @$files );
}

sub on_open {
	my $self     = shift;
	my $filename = $self->current->filename;
	if ( $filename ) {
		$default_dir = File::Basename::dirname($filename);
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
	my $self     = shift;
	my $document = $self->current->document or return;
	if ( $document->reload ) {
		$document->editor->configure_editor($document);
	} else {
		$self->error( sprintf(
			Wx::gettext("Could not reload file: %s"),
			$document->errstr
		) );
	}
	return;
}

# Returns true if saved.
# Returns false if cancelled.
sub on_save_as {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $current  = $document->filename;
	if ( defined $current ) {
		$default_dir = File::Basename::dirname($current);
	}
	while ( 1 ) {
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
			my $response = Wx::MessageBox(
				Wx::gettext("File already exists. Overwrite it?"),
				Wx::gettext("Exist"),
				Wx::wxYES_NO,
				$self,
			);
			if ( $response == Wx::wxYES ) {
				$document->_set_filename($path);
				$document->set_newline_type(Padre::Util::NEWLINE);
				last;
			}
		} else {
			$document->_set_filename($path);
			$document->set_newline_type(Padre::Util::NEWLINE);
			last;
		}
	}
	my $pageid = $self->notebook->GetSelection;
	$self->_save_buffer($pageid);

	$document->set_mimetype( $document->guess_mimetype );
	$document->editor->padre_setup;
	$document->rebless;

	$self->refresh;

	return 1;
}

sub on_save {
	my $self     = shift;
	my $document = $self->current->document or return;

	if ( $document->is_new ) {
		return $self->on_save_as;
	}
	if ( $document->is_modified ) {
		my $pageid = $self->notebook->GetSelection;
		$self->_save_buffer($pageid);
	}

	return;
}

# Returns true if all saved.
# Returns false if cancelled.
sub on_save_all {
	my $self = shift;
	foreach my $id ( $self->pageids ) {
		my $doc = $self->notebook->GetPage($id) or next;
		$self->on_save( $doc ) or return 0;
	}
	return 1;
}

sub _save_buffer {
	my ($self, $id) = @_;

	my $page = $self->notebook->GetPage($id);
	my $doc  = $page->{Document} or return;

	if ( $doc->has_changed_on_disk ) {
		my $ret = Wx::MessageBox(
			Wx::gettext("File changed on disk since last saved. Do you want to overwrite it?"),
			$doc->filename || Wx::gettext("File not in sync"),
			Wx::wxYES_NO|Wx::wxCENTRE,
			$self,
		);
		return if $ret != Wx::wxYES;
	}

	unless ( $doc->save_file ) {
		Wx::MessageBox(
			Wx::gettext("Could not save file: ") . $doc->errstr,
			Wx::gettext("Error"),
			Wx::wxOK,
			$self,
		);
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
	$self->{no_syntax_check_refresh} = 1;
	$self->refresh;
}

sub close {
	my $self     = shift;
	my $notebook = $self->notebook;
	my $id       = shift;
	unless ( defined $id ) {
		$id = $notebook->GetSelection;
	}
	return if $id == -1;

	my $editor = $notebook->GetPage($id) or return;
	my $doc    = $editor->{Document}     or return;

	local $self->{_no_refresh} = 1;

	if ( $doc->is_modified and not $doc->is_unused ) {
		my $ret = Wx::MessageBox(
			Wx::gettext("File changed. Do you want to save it?"),
			$doc->filename || Wx::gettext("Unsaved File"),
			Wx::wxYES_NO
			| Wx::wxCANCEL
			| Wx::wxCENTRE,
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
	$self->notebook->DeletePage($id);

	# Remove the entry from the Window menu
	$self->menu->window->refresh($self->current);

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
	return $self->_close_all( $self->notebook->GetSelection );
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
	my $page = $self->notebook->GetPage($id);
	if ($page) {
		$self->notebook->SetSelection($id);
		$self->refresh_status($self->current);
		$page->{Document}->set_indentation_style(); # TODO: encapsulation?
		return 1;
	}

	return;
}

sub on_next_pane {
	my ($self) = @_;

	my $count = $self->notebook->GetPageCount;
	return if not $count;

	my $id    = $self->notebook->GetSelection;
	if ($id + 1 < $count) {
		$self->on_nth_pane($id + 1);
	} else {
		$self->on_nth_pane(0);
	}
	return;
}

sub on_prev_pane {
	my ($self) = @_;
	my $count = $self->notebook->GetPageCount;
	return if not $count;
	my $id    = $self->notebook->GetSelection;
	if ($id) {
		$self->on_nth_pane($id - 1);
	} else {
		$self->on_nth_pane($count-1);
	}
	return;
}

sub on_diff {
	my $self     = shift;
	my $document = Padre::Current->document or return;
	my $text     = $document->text_get;
	my $file     = $document->filename;
	unless ( $file ) {
		return $self->error(Wx::gettext("Cannot diff if file was never saved"));
	}

	require Text::Diff;
	my $diff = Text::Diff::diff( $file, \$text );
	unless ( $diff ) {
		$diff = Wx::gettext("There are no differences\n");
	}

	$self->show_output(1);
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
	$_[0]->ShowFullScreen( ! $_[0]->IsFullScreen );
}

#
# on_join_lines()
#
# join current line with next one (a-la vi with Ctrl+J)
#
sub on_join_lines {
	my $self = shift;
	my $page = $self->current->editor;

	# find positions
	my $pos1 = $page->GetCurrentPos;
	my $line = $page->LineFromPosition($pos1);
	my $pos2 = $page->PositionFromLine($line + 1);

	# mark target & join lines
	$page->SetTargetStart($pos1);
	$page->SetTargetEnd($pos2);
	$page->LinesJoin;
}

###### preferences and toggle functions

sub zoom {
	my $self = shift;
	my $zoom = $self->current->editor->GetZoom + shift;
	foreach my $page ( $self->pages ) {
		$page->SetZoom($zoom);
	}
}

sub on_preferences {
	my $self = shift;

	require Padre::Wx::Dialog::Preferences;
	if ( Padre::Wx::Dialog::Preferences->run( $self )) {
		foreach my $editor ( $self->pages ) {
			$editor->set_preferences;
		}
		$self->refresh_methods($self->current);
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
		if ( $config->{editor_codefolding} == 0 ) {
			$editor->unfold_all;
		}
	}

	return;
}

sub on_toggle_current_line_background {
	my ($self, $event) = @_;

	my $config = Padre->ide->config;
	$config->{editor_current_line_background} = $event->IsChecked ? 1 : 0;

	foreach my $editor ( $self->pages ) {
		$editor->SetCaretLineVisible( $config->{editor_current_line_background} ? 1 : 0 );
	}

	return;
}

sub on_toggle_syntax_check {
	my ($self, $event) = @_;

	my $config = Padre->ide->config;
	$config->{editor_syntaxcheck} = $event->IsChecked ? 1 : 0;

	$self->syntax_checker->enable( $config->{editor_syntaxcheck} ? 1 : 0 );

	return;
}

sub on_toggle_errorlist {
	my ($self, $event) = @_;

	my $config = Padre->ide->config;
	$config->{editor_errorlist} = $event->IsChecked ? 1 : 0;

	$config->{editor_errorlist} ? $self->errorlist->enable : $self->errorlist->disable;

	return;
}

sub on_toggle_indentation_guide {
	my $self   = shift;

	my $config = Padre->ide->config;
	$config->{editor_indentationguides} = $self->menu->view->{indentation_guide}->IsChecked ? 1 : 0;

	foreach my $editor ( $self->pages ) {
		$editor->SetIndentationGuides( $config->{editor_indentationguides} );
	}

	return;
}

sub on_toggle_eol {
	my $self   = shift;

	my $config = Padre->ide->config;
	$config->{editor_eol} = $self->menu->view->{eol}->IsChecked ? 1 : 0;

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
	$config->{editor_whitespaces} = $self->menu->view->{whitespaces}->IsChecked
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
	unless ( $on == $self->menu->view->{word_wrap}->IsChecked ) {
		$self->menu->view->{word_wrap}->Check($on);
	}
	
	my $doc = $self->current->document or return;

	if ( $on ) {
		$doc->editor->SetWrapMode( Wx::wxSTC_WRAP_WORD );
	} else {
		$doc->editor->SetWrapMode( Wx::wxSTC_WRAP_NONE );
	}
}

sub show_output {
	my $self = shift;
	my $on   = @_ ? $_[0] ? 1 : 0 : 1;
	unless ( $on == $self->menu->view->{output}->IsChecked ) {
		$self->menu->view->{output}->Check($on);
	}

	my $bp = \$self->{gui}->{bottompane};
	my $op = \$self->{gui}->{output_panel};

	if ( $on ) {
		my $idx = ${$bp}->GetPageIndex(${$op});
		if ( $idx >= 0 ) {
			${$bp}->SetSelection($idx);
		}
		else {
			${$bp}->InsertPage(
				0,
				${$op},
				Wx::gettext("Output"),
				1,
				# Padre::Wx::tango( 'mimetypes', 'text-x-generic.png' )
			);
			${$op}->Show;
			$self->check_pane_needed('bottompane');
		}
	} else {
		my $idx = ${$bp}->GetPageIndex(${$op});
		${$op}->Hide;
		if ( $idx >= 0 ) {
			${$bp}->RemovePage($idx);
			$self->check_pane_needed('bottompane');
		}
	}
	$self->manager->Update;
	Padre->ide->config->{main_output_panel} = $on;

	return;
}

sub show_functions {
	my $self = shift;
	my $on   = ( @_ ? ($_[0] ? 1 : 0) : 1 );

	my $sp = \$self->{gui}->{sidepane};
	my $fp = \$self->{gui}->{subs_panel};

	unless ( $on == $self->menu->view->{functions}->IsChecked ) {
		$self->menu->view->{functions}->Check($on);
	}

	if ( $on ) {
		# $self->refresh_methods();
		my $idx = ${$sp}->GetPageIndex(${$fp});
		if ( $idx >= 0 ) {
			${$sp}->SetSelection($idx);
		}
		else {
			${$sp}->InsertPage(
				0,
				${$fp},
				Wx::gettext("Subs"),
				1,
			);
			${$fp}->Show;
			$self->check_pane_needed('sidepane');
		}
	} else {
		my $idx = ${$sp}->GetPageIndex(${$fp});
		${$fp}->Hide;
		if ( $idx >= 0 ) {
			${$sp}->RemovePage($idx);
			$self->check_pane_needed('sidepane');
		}
	}
	$self->manager->Update;
	Padre->ide->config->{main_subs_panel} = $on;

	return;
}

sub show_syntaxbar {
	my $self = shift;
	my $on   = scalar(@_) ? $_[0] ? 1 : 0 : 1;

	my $bp = \$self->{gui}->{bottompane};
	my $sp = \$self->{gui}->{syntaxcheck_panel};

	unless ( $on == $self->menu->view->{show_syntaxcheck}->IsChecked ) {
		$self->menu->view->{show_syntaxcheck}->Check($on);
	}

	if ( $on ) {
		my $idx = ${$bp}->GetPageIndex(${$sp});
		if ( $idx >= 0 ) {
			${$bp}->SetSelection($idx);
		}
		else {
			${$bp}->InsertPage(
				1,
				${$sp},
				Wx::gettext("Syntax Check"),
				1,
				# Padre::Wx::tango( 'status', 'dialog-warning.png' )
			);
			${$sp}->Show;
			$self->check_pane_needed('bottompane');
		}
	}
	else {
		my $idx = ${$bp}->GetPageIndex(${$sp});
		${$sp}->Hide;
		if ( $idx >= 0 ) {
			${$bp}->RemovePage($idx);
			$self->check_pane_needed('bottompane');
		}
	}
	$self->manager->Update;

	return;
}

sub check_pane_needed {
	my ( $self, $pane ) = @_;

	my $visible = 0;
	my $cnt = $self->{gui}->{$pane}->GetPageCount;

	foreach my $num ( 0 .. $cnt ) {
		# ignore 'Ack' pane
		if ( $pane eq 'bottompane' ) {
			my $ack_page_idx = $self->{gui}->{$pane}->GetPageIndex( $self->{gui}->{ack_panel} );
			next if ( defined $ack_page_idx and $ack_page_idx == $num );
		}
		
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

sub on_toggle_statusbar {
	my ($self, $event) = @_;
	if ( Padre::Util::WIN32 ) {
		# Status bar always shown on Windows
		return;
	}

	# Update the configuration
	my $config = Padre->ide->config;
	$config->{main_statusbar} = $self->menu->view->{statusbar}->IsChecked ? 1 : 0;

	# Update the status bar
	my $status_bar = $self->GetStatusBar;
	if ( $config->{main_statusbar} ) {
		$status_bar->Show;
	} else {
		$status_bar->Hide;
	}

	return;
}

sub on_toggle_lockpanels {
	my $self  = shift;
	my $event = shift;

	# Update the configuration
	my $config = Padre->ide->config;
	$config->{main_lockpanels} = $self->menu->view->{lock_panels}->IsChecked ? 1 : 0;

	# Update the lock status
	$self->manager->lock_panels($config->{main_lockpanels});

	return;
}

sub on_insert_from_file {
	my $self = shift;
	my $id   = $self->notebook->GetSelection;
	return if $id == -1;

	# popup the window
	my $last_filename = $self->current->filename;
	if ( $last_filename ) {
		$default_dir = File::Basename::dirname($last_filename);
	}
	my $dialog = Wx::FileDialog->new(
		$self,
		Wx::gettext('Open file'),
		$default_dir,
		'',
		'*.*',
		Wx::wxFD_OPEN,
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
	
	my $editor = $self->notebook->GetPage($id);
	$editor->ReplaceSelection('');
	my $pos = $editor->GetCurrentPos;
	$editor->InsertText( $pos, $text );
	$editor->GotoPos( $pos + $length - 1 );
}

sub convert_to {
	my $self    = shift;
	my $newline = shift;
	my $current = $self->current;
	my $editor  = $current->editor;
	$editor->ConvertEOLs( $Padre::Wx::Editor::mode{$newline} );

	# TODO: include the changing of file type in the undo/redo actions
	# or better yet somehow fetch it from the document when it is needed.
	my $document = $current->document or return;
	$document->set_newline_type($newline);

	$self->refresh;
}

sub find_editor_of_file {
	my $self     = shift;
	my $file     = shift;
	my $notebook = $self->notebook;
	foreach my $id ( $self->pageids ) {
		my $editor   = $notebook->GetPage($id) or return;
		my $document = $editor->{Document}     or return;
		my $filename = $document->filename     or next;
		return $id if $filename eq $file;
	}
	return;
}

sub run_in_padre {
	my $self = shift;
	my $doc  = $self->current->document or return;
	my $code = $doc->text_get;
	eval $code; ## no critic
	if ( $@ ) {
		Wx::MessageBox(
			sprintf(Wx::gettext("Error: %s"), $@),
			Wx::gettext("Internal error"),
			Wx::wxOK,
			$self,
		);
	}
	return;
}

sub on_function_selected {
	my $self     = shift;
	my $event    = shift;
	my $subname  = $event->GetItem->GetText or return;
	my $document = $self->current->document;
	my $editor   = $document->editor;

	# Locate the function
	my ($start, $end) = Padre::Util::get_matches(
		$editor->GetText,
		$document->get_function_regex($subname),
		$editor->GetSelection, # Provides two params
	);
	return unless defined $start; # Couldn't find it

	# Move the selection to the sub location
	$editor->GotoPos($start);
	$editor->ScrollToLine(
		$editor->GetCurrentLine - ($editor->LinesOnScreen / 2)
	);
	$editor->SetFocus;

	# $editor->SetCurrentPos($start);
	# $editor->goto_pos_centerize($start);

	return;
}

## STC related functions

sub on_stc_style_needed {
	my ( $self, $event ) = @_;

	my $doc = Padre::Current->document or return;
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
	my $self    = shift;

	# Avoid recursion
	return if $self->{_in_stc_update_ui};
	local $self->{_in_stc_update_ui} = 1;

	# Check for brace, on current position, higlight the matching brace
	my $current = $self->current;
	my $editor  = $current->editor;
	$editor->highlight_braces;
	$editor->show_calltip;

	# avoid refreshing the subs as that takes a lot of time
	# TODO maybe we should refresh it on every 20s hit or so
	$self->refresh_menu($current);
	$self->refresh_toolbar($current);
	$self->refresh_status($current);
	#$self->refresh_methods;
	#$self->refresh_syntaxcheck;

	return;
}

sub on_stc_change {
	return;
}

# http://www.yellowbrain.com/stc/events.html#EVT_STC_CHARADDED
# TODO: maybe we need to check this more carefully.
sub on_stc_char_added {
	my $self  = shift;
	my $event = shift;
	my $key   = $event->GetKey;
	if ( $key == 10 ) { # ENTER
		$self->current->editor->autoindent('indent');
	} elsif ( $key == 125 ) { # Closing brace
		$self->current->editor->autoindent('deindent');
	}
	return;
}

sub on_stc_dwell_start {
	my ($self, $event) = @_;

	# print Data::Dumper::Dumper $event;
	my $editor = $self->current->editor;
	# print "dwell: ", $event->GetPosition, "\n";
	# $editor->show_tooltip;
	# print Wx::GetMousePosition, "\n";
	# print Wx::GetMousePositionXY, "\n";

	return;
}

sub on_close_pane {
	my ( $self, $event ) = @_;
	my $pane = $event->GetPane;
}

sub on_doc_stats {
	my ($self, $event) = @_;

	my $doc = $self->current->document;
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
		sprintf(Wx::gettext("Document type: %s"),        (defined ref($doc) ? ref($doc) : Wx::gettext("none"))),
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
	my $self    = shift;
	my $type    = shift;
	my $current = $self->current;
	my $doc     = $current->document or return;
	my $title   = $type eq 'Space_to_Tab'
		? Wx::gettext('Space to Tab')
		: Wx::gettext('Tab to Space');

	my $dialog = Padre::Wx::History::TextDialog->new(
		$self, Wx::gettext('How many spaces for each tab:'), $title, $type,
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $space_num = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $space_num and $space_num =~ /^\d+$/ ) {
		return;
	}
	
	my $src  = $current->text;
	my $code = ( $src ) ? $src : $doc->text_get;
	
	return unless ( defined $code and length($code) );
	
	my $to_space = ' ' x $space_num;
	if ( $type eq 'Space_to_Tab' ) {
		$code =~ s/^(\s+)/my $s = $1; $s =~ s{$to_space}{\t}g; $s/mge;
	} else {
		$code =~ s/^(\s+)/my $s = $1; $s =~ s{\t}{$to_space}g; $s/mge;
	}
	
	if ( $src ) {
		my $editor = $current->editor;
		$editor->ReplaceSelection( $code );
	} else {
		$doc->text_set( $code );
	}
}

sub on_delete_ending_space {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document or return;	
	my $src      = $current->text;
	my $code     = defined($src) ? $src : $document->text_get;

	# Remove ending space
	$code =~ s/([^\n\S]+)$//mg;
	
	if ( $src ) {
		my $editor = $current->editor;
		$editor->ReplaceSelection( $code );
	} else {
		$document->text_set( $code );
	}
}

sub on_delete_leading_space {
	my $self    = shift;
	my $current = $self->current;
	my $src     = $current->text;
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
	
	my $editor = $current->editor;
	$editor->ReplaceSelection( $code );
}

# TODO next function
# should be in a class representing the subs panel
sub on_subs_panel_left {
	my ($self, $event) = @_;
	my $main = Padre->ide->wx->main_window;
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
	my $doc  = $self->current->document or return;

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
		foreach my $i ( $self->pageids ) {
			my $editor = $_[0]->notebook->GetPage($i);
			if ( Scalar::Util::refaddr($editor) eq Scalar::Util::refaddr($_[0]->{page_history}[-1]) ) {
				$self->notebook->SetSelection($i);
				last;
			}
		}

		# Partial refresh
		$self->refresh_status($self->current);
		$self->refresh_toolbar($self->current);
	}
}

sub on_notebook_page_changed {
	my $editor = $_[0]->current->editor;
	if ( $editor ) {
		my $history = $_[0]->{page_history};
		@$history = grep {
			Scalar::Util::refaddr($_) ne Scalar::Util::refaddr($editor)
		} @$history;
		push @$history, $editor;

		# Update indentation in case auto-update is on
		# TODO: encapsulation?
		$editor->{Document}->set_indentation_style;
	}
	$_[0]->refresh;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
