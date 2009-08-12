package Padre::Wx::Main;

=pod

=head1 NAME

Padre::Wx::Main - The main window for the Padre IDE

=head1 DESCRIPTION

C<Padre::Wx::Main> implements Padre's main window. It is the window
containing the menus, the notebook with all opened tabs, the various sub-
windows (outline, subs, output, errors, etc).

It inherits from C<Wx::Frame>, so check wx documentation to see all
the available methods that can be applied to it besides the added ones
(see below).

=cut

use 5.008;
use strict;
use warnings;
use FindBin;
use Cwd            ();
use Carp           ();
use File::Spec     ();
use File::HomeDir  ();
use File::Basename ();
use File::Temp     ();
use List::Util     ();
use Scalar::Util   ();
use Params::Util qw{_INSTANCE};
use Padre::Constant ();
use Padre::Util     ();
use Padre::Perl     ();
use Padre::Locale   ();
use Padre::Current qw{_CURRENT};
use Padre::Document           ();
use Padre::DB                 ();
use Padre::Wx                 ();
use Padre::Wx::Icon           ();
use Padre::Wx::Left           ();
use Padre::Wx::Right          ();
use Padre::Wx::Bottom         ();
use Padre::Wx::Editor         ();
use Padre::Wx::Output         ();
use Padre::Wx::Syntax         ();
use Padre::Wx::Menubar        ();
use Padre::Wx::ToolBar        ();
use Padre::Wx::Notebook       ();
use Padre::Wx::StatusBar      ();
use Padre::Wx::ErrorList      ();
use Padre::Wx::AuiManager     ();
use Padre::Wx::FunctionList   ();
use Padre::Wx::FileDropTarget ();

our $VERSION = '0.42';
our @ISA     = 'Wx::Frame';

use constant SECONDS => 1000;

=pod

=head1 PUBLIC API

=head2 Constructor

There's only one constructor for this class.

=head3 new

    my $main = Padre::Wx::Main->new($ide);

Create and return a new Padre main window. One should pass a C<Padre>
object as argument, to get a reference to the Padre application.

=cut

# NOTE: Yes this method does get a little large, but that's fine.
#       It's better to have one bigger method that is easily
#       understandable rather than scattering tightly-related code
#       all over the file in unrelated places.
#       If you feel the need to make this smaller, try to make each
#       individual step tighter and better abstracted.
sub new {
	my $class = shift;
	my $ide = shift;
	unless ( _INSTANCE( $ide, 'Padre' ) ) {
		Carp::croak("Did not provide an ide object to Padre::Wx::Main->new");
	}

	# Bootstrap some Wx internals
	my $config = $ide->config;
	Wx::Log::SetActiveTarget( Wx::LogStderr->new );
	Padre::Util::set_logging( $config->logging );
	Padre::Util::set_trace( $config->logging_trace );
	Padre::Util::debug('Logging started');
	Wx::InitAllImageHandlers();

	# Determine the window title
	my $title = 'Padre';
	if ( $0 =~ /padre$/ ) {
		my $dir = $0;
		$dir =~ s/padre$//;
		my $revision = Padre::Util::svn_directory_revision($dir);
		if ( -d "$dir.svn" ) {
			$title .= " SVN \@$revision (\$VERSION = $Padre::VERSION)";
		}
	}

	# Determine the initial frame style
	my $style = Wx::wxDEFAULT_FRAME_STYLE;
	if ( $config->main_maximized ) {
		$style |= Wx::wxMAXIMIZE;
		$style |= Wx::wxCLIP_CHILDREN;
	}

	# Create the underlying Wx frame
	my $self = $class->SUPER::new(
		undef, -1, $title,
		[   $config->main_left,
			$config->main_top,
		],
		[   $config->main_width,
			$config->main_height,
		],
		$style,
	);

	# Save a reference back to the parent IDE
	$self->{ide} = $ide;

	# Save a reference to the configuration object.
	# This prevents tons of ide->config
	$self->{config} = $config;

	# Remember the original title we used for later
	$self->{title} = $title;

	# Having recorded the "current working directory" move
	# the OS directory cursor away from this directory, so
	# that Padre won't hold a lock on the current directory.
	# If changing the directory fails, ignore errors (for now)
	$self->{cwd} = Cwd::cwd();
	chdir( File::HomeDir->my_home );

	# A large complex application looks, frankly, utterly stupid
	# if it gets very small, or even mildly small.
	$self->SetMinSize( Wx::Size->new( 500, 400 ) );

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
	$self->{aui} = Padre::Wx::AuiManager->new($self);

	# Add some additional attribute slots
	$self->{marker} = {};

	# Create the menu bar
	$self->{menu} = Padre::Wx::Menubar->new($self);
	$self->SetMenuBar( $self->{menu}->wx );

	# Create the tool bar
	$self->SetToolBar( Padre::Wx::ToolBar->new($self) );
	$self->GetToolBar->Realize;

	# Create the status bar
	my $statusbar = Padre::Wx::StatusBar->new($self);
	$self->SetStatusBar($statusbar);

	# Create the notebooks (document and tools) that
	# serve as the main AUI manager GUI elements.
	$self->{notebook} = Padre::Wx::Notebook->new($self);
	$self->{left}     = Padre::Wx::Left->new($self);
	$self->{right}    = Padre::Wx::Right->new($self);
	$self->{bottom}   = Padre::Wx::Bottom->new($self);

	# Creat the various tools that will live in the panes
	$self->{output}    = Padre::Wx::Output->new($self);
	$self->{syntax}    = Padre::Wx::Syntax->new($self);
	$self->{functions} = Padre::Wx::FunctionList->new($self);
	$self->{errorlist} = Padre::Wx::ErrorList->new($self);

	# Set up the pane close event
	Wx::Event::EVT_AUI_PANE_CLOSE(
		$self,
		sub {
			$_[0]->on_aui_pane_close( $_[1] );
		},
	);

	# Special Key Handling
	Wx::Event::EVT_KEY_UP(
		$self,
		sub {
			shift->key_up(@_);
		},
	);

	# Deal with someone closing the window
	Wx::Event::EVT_CLOSE(
		$self,
		sub {
			shift->on_close_window(@_);
		},
	);

	# Scintilla Event Hooks
	Wx::Event::EVT_STC_UPDATEUI( $self, -1, \&on_stc_update_ui );
	Wx::Event::EVT_STC_CHANGE( $self, -1, \&on_stc_change );
	Wx::Event::EVT_STC_STYLENEEDED( $self, -1, \&on_stc_style_needed );
	Wx::Event::EVT_STC_CHARADDED( $self, -1, \&on_stc_char_added );
	Wx::Event::EVT_STC_DWELLSTART( $self, -1, \&on_stc_dwell_start );

	# As ugly as the WxPerl icon is, the new file toolbar image we
	# used to use was far uglier
	# Wx::GetWxPerlIcon()
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# Show the tools that the configuration dictates
	$self->show_functions( $self->config->main_functions );
	$self->show_outline( $self->config->main_outline );
	$self->show_directory( $self->config->main_directory );
	$self->show_output( $self->config->main_output );

	# Lock the panels if needed
	$self->aui->lock_panels( $self->config->main_lockinterface );

	# we need an event immediately after the window opened
	# (we had an issue that if the default of main_statusbar was false it did
	# not show the status bar which is ok, but then when we selected the menu
	# to show it, it showed at the top) so now we always turn the status bar on
	# at the beginning and hide it in the timer, if it was not needed
	# TODO: there might be better ways to fix that issue...
	$statusbar->Show;
	my $timer = Wx::Timer->new(
		$self,
		Padre::Wx::ID_TIMER_POSTINIT,
	);
	Wx::Event::EVT_TIMER(
		$self,
		Padre::Wx::ID_TIMER_POSTINIT,
		sub {
			$_[0]->_timer_post_init;
		},
	);
	$timer->Start( 1, 1 );

	return $self;
}





#####################################################################

=pod

=head2 Accessors

The following methods access the object attributes. They are both
getters and setters, depending on whether you provide them with an
argument. Use them wisely.

Accessors to GUI elements:

=over 4

=item * title

=item * config

=item * aui

=item * menu

=item * notebook

=item * left

=item * right

=item * functions

=item * outline

=item * directory

=item * bottom

=item * output

=item * syntax

=item * errorlist

=back

Accessors to operating data:

=over 4

=item * cwd

=item * no_refresh

=back

Accessors that may not belong to this class:

=over 4

=item * ack

=back

=cut

use Class::XSAccessor
	predicates => {
		# Needed for lazily-constructed gui elements
		has_about     => 'about',
		has_find      => 'find',
		has_replace   => 'replace',
		has_outline   => 'outline',
		has_directory => 'directory',
	},
	getters => {
		# GUI Elements
		title     => 'title',
		config    => 'config',
		ide       => 'ide',
		aui       => 'aui',
		menu      => 'menu',
		notebook  => 'notebook',
		left      => 'left',
		right     => 'right',
		functions => 'functions',
		bottom    => 'bottom',
		output    => 'output',
		syntax    => 'syntax',
		errorlist => 'errorlist',

		# Operating Data
		cwd        => 'cwd',
		search     => 'search',
		no_refresh => '_no_refresh',

		# Things that are probably in the wrong place
		ack => 'ack',
	};

sub about {
	my $self = shift;
	unless ( defined $self->{about} ) {
		require Padre::Wx::About;
		$self->{about} = Padre::Wx::About->new($self);
	}
	return $self->{about};
}

sub outline {
	my $self = shift;
	unless ( defined $self->{outline} ) {
		require Padre::Wx::Outline;
		$self->{outline} = Padre::Wx::Outline->new($self);
	}
	return $self->{outline};
}

sub directory {
	my $self = shift;
	unless ( defined $self->{directory} ) {
		require Padre::Wx::Directory;
		$self->{directory} = Padre::Wx::Directory->new($self);
	}
	return $self->{directory};
}

sub directory_panel {
	my $self = shift;
	my $side = $self->config->main_directory_panel;
	return $self->$side();
}

sub open_resource {
	my $self = shift;
	unless ( defined $self->{open_resource} ) {
		require Padre::Wx::Dialog::OpenResource;
		$self->{open_resource} = Padre::Wx::Dialog::OpenResource->new($self);
	}
	return $self->{open_resource};
}

sub help_search {
	my $self = shift;
	unless ( defined $self->{help_search} ) {
		require Padre::Wx::Dialog::HelpSearch;
		$self->{help_search} = Padre::Wx::Dialog::HelpSearch->new($self);
	}
	return $self->{help_search};
}

=pod

=head3 find

    my $find = $main->find;

Returns the find dialog, creating a new one if needed.

=cut

sub find {
	my $self = shift;
	unless ( defined $self->{find} ) {
		require Padre::Wx::Dialog::Find;
		$self->{find} = Padre::Wx::Dialog::Find->new($self);
	}
	return $self->{find};
}

=pod

=head3 fast_find

    my $find = $main->fast_find;

Return current quick find dialog. Create a new one if needed.

=cut

sub fast_find {
	my $self = shift;
	unless ( defined $self->{fast_find} ) {
		require Padre::Wx::Dialog::Search;
		$self->{fast_find} = Padre::Wx::Dialog::Search->new;
	}
	return $self->{fast_find};
}

=pod

=head3 replace

    my $replace = $main->replace;

Return current replace dialog. Create a new one if needed.

=cut

sub replace {
	my $self = shift;
	unless ( defined $self->{replace} ) {
		require Padre::Wx::Dialog::Replace;
		$self->{replace} = Padre::Wx::Dialog::Replace->new($self);
	}
	return $self->{replace};
}

=pod

=head2 Public Methods

=head3 load_files

    $main->load_files;

Load any default files: session from command-line, explicit list on command-
line, or last session if user has this setup, a new file, or nothing.

=cut

sub load_files {
	my $self    = shift;
	my $ide     = $self->ide;
	my $config  = $self->config;
	my $startup = $config->main_startup;

	# explicit session on command line takes precedence
	if ( defined $ide->opts->{session} ) {

		# try to find the wanted session...
		my ($session) = Padre::DB::Session->select(
			'where name = ?',
			$ide->opts->{session},
		);

		# ... and open it.
		if ( defined $session ) {
			$self->open_session($session);
		} else {
			my $error = sprintf(
				Wx::gettext('No such session %s'),
				$ide->opts->{session},
			);
			$self->error($error);
		}
		return;
	}

	# otherwise, an explicit list on the command line overrides configuration
	my $files = $ide->{ARGV};
	if ( Params::Util::_ARRAY($files) ) {
		$self->setup_editors(@$files);
		return;
	}

	# Config setting 'last' means startup with all the files from the
	# previous time we used Padre open (if they still exist)
	if ( $startup eq 'last' ) {
		my $session = Padre::DB::Session->last_padre_session;
		$self->open_session($session) if defined($session);
		return;
	}

	# Config setting 'nothing' means startup with nothing open
	if ( $startup eq 'nothing' ) {
		return;
	}

	# Config setting 'new' means startup with a single new file open
	if ( $startup eq 'new' ) {
		$self->setup_editors;
		return;
	}

	# Configuration has an entry we don't know about
	# TODO: Once we have a warning system more useful than STDERR
	# add a warning. For now though, just do nothing and ignore.
	return;
}

sub _timer_post_init {
	my $self    = shift;
	my $config  = $self->config;
	my $manager = $self->ide->plugin_manager;

	# Do an initial Show/paint of the complete-looking main window
	# without any files loaded. Then immediately Freeze so that the
	# loading of the files is done in a single render pass.
	# This gives us an optimum compromise between being PERCEIVED
	# to startup quickly, and ACTUALLY starting up quickly.
	$self->Show(1);
	$self->Freeze;

	# If the position mandated by the configuration is now
	# off the screen (typically because we've changed the screen
	# size, reposition to the defaults).
	unless ( $self->IsShownOnScreen ) {
		$self->SetSize(
			Wx::Size->new(
				$config->default('main_width'),
				$config->default('main_height'),
			)
		);
		$self->CentreOnScreen;
	}

	# Load all files and refresh the application so that it
	# represents the loaded state.
	$self->load_files;

	# Cannot use the toggle sub here as that one reads from the Menu and
	# on some machines the Menu is not configured yet at this point.
	if ( $config->main_statusbar ) {
		$self->GetStatusBar->Show;
	} else {
		$self->GetStatusBar->Hide;
	}
	$manager->enable_editors_for_all;

	$self->show_syntax( $config->main_syntaxcheck );
	if ( $config->main_errorlist ) {
		$self->errorlist->enable;
	}

	$self->refresh;

	# Now we are fully loaded and can paint continuously
	$self->Thaw;

	# Start the single instance server
	if ( $config->main_singleinstance ) {
		$self->single_instance_start;
	}

	# Check for new plugins and alert the user to them
	$manager->alert_new;

	# Start the change detection timer
	my $timer = Wx::Timer->new( $self, Padre::Wx::ID_TIMER_FILECHECK );
	Wx::Event::EVT_TIMER(
		$self,
		Padre::Wx::ID_TIMER_FILECHECK,
		sub {
			$_[0]->timer_check_overwrite;
		},
	);
	$timer->Start( $self->ide->config->update_file_from_disk_interval * SECONDS, 0 );

	return;
}

=pod

=head2 freezer

   my $locker = $main->freezer;

Create and return an automatic Freeze object that Thaw's on destruction.

=cut

sub freezer {
	Wx::WindowUpdateLocker->new( $_[0] );
}

=pod

=head2 Single Instance Server

Padre embeds a small network server to handle single instance. Here are
the methods that allow to control this embedded server.

=cut

my $single_instance_port = 4444;

=pod

=head3 single_instance_start

    $main->single_instance_start;

Start the embedded server. Create it if it doesn't exist. Return true on
success, die otherwise.

=cut

sub single_instance_start {
	my $self = shift;

	# check if server is already started
	return 1 if $self->single_instance_running;

	# Create the server
	require Wx::Socket;
	$self->{single_instance} = Wx::SocketServer->new(
		'127.0.0.1' => $single_instance_port,
		Wx::wxSOCKET_NOWAIT Wx::wxSOCKET_REUSEADDR,
	);
	unless ( $self->{single_instance}->Ok ) {
		delete $self->{single_instance_server};
		warn( Wx::gettext("Failed to create server") );
	}
	Wx::Event::EVT_SOCKET_CONNECTION(
		$self,
		$self->{single_instance},
		sub {
			$self->single_instance_connect( $_[0] );
		}
	);

	return 1;
}

=pod

=head3 single_instance_stop

    $main->single_instance_stop;

Stop & destroy the embedded server if it was running. Return true
on success.

=cut

sub single_instance_stop {
	my $self = shift;

	# server already terminated, nothing to do
	return 1 unless $self->single_instance_running;

	# Terminate the server
	$self->{single_instance}->Close;
	delete( $self->{single_instance} )->Destroy;

	return 1;
}

=pod

=head3 single_instance_running

    my $is_running = $main->single_instance_running;

Return true if the embedded server is currently running.

=cut

sub single_instance_running {
	return defined $_[0]->{single_instance};
}

=pod

=head3 single_instance_connect

    $main->single_instance_connect;

Callback called when a client is connecting to embedded server. This is
the case when user starts a new Padre, and preference "open all
documents in single Padre instance" is checked.

=cut

sub single_instance_connect {
	my $self   = shift;
	my $server = shift;
	my $client = $server->Accept(0);

	# Before we start accepting input,
	# send the client our process ID.
	$client->Write( sprintf( '% 10s', $$ ), 10 );

	# Set up the socket hooks
	Wx::Event::EVT_SOCKET_INPUT(
		$self, $client,
		sub {

			# Accept the data and stream commands
			my $command = '';
			my $buffer  = '';
			while ( $_[0]->Read( $buffer, 128 ) ) {
				$command .= $buffer;
				while ( $command =~ s/^(.*?)[\012\015]+//s ) {
					$_[1]->single_instance_command("$1");
				}
			}
			return 1;
		}
	);
	Wx::Event::EVT_SOCKET_LOST(
		$self, $client,
		sub {
			$_[0]->Destroy;
		}
	);

	return 1;
}

=pod

=head3 single_instance_command

    $main->single_instance_command( $line );

Callback called when a client has issued a command C<$line> while
connected on embedded server. Current supported commands are C<open
$file> and C<focus>.

=cut

sub single_instance_command {
	my $self = shift;
	my $line = shift;

	# $line should be defined
	return 1 unless defined $line && length $line;

	# ignore the line if command isn't plain ascii
	return 1 unless $line =~ s/^(\S+)\s*//s;

	if ( $1 eq 'focus' ) {

		# try to give focus to padre ide. it might not work,
		# since some window manager implement some kind of focus-
		# stealing prevention.

		# first, let's deiconize padre if needed
		$self->Iconize(0) if $self->IsIconized;

		# now, let's raise padre

		# We have to do both or (on Win32 at least)
		# the Raise call only works the first time.
		$self->Lower;
		$self->Raise;

	} elsif ( $1 eq 'open' ) {
		if ( -f $line ) {

			# If a file is already loaded switch to it instead
			$self->notebook->show_file($line)
				or $self->setup_editors($line);
		}

	} else {

		# d'oh! embedded server can't do anything
		warn("Unsupported command '$1'");
	}

	return 1;
}

=pod

=head2 Window Methods

Those methods allow to query properties about the main window.

=head3 window_width

    my $width = $main->window_width;

Return the main window width.

=cut

sub window_width {
	( $_[0]->GetSizeWH )[0];
}

=pod

=head3 window_height

    my $width = $main->window_height;

Return the main window height.

=cut

sub window_height {
	( $_[0]->GetSizeWH )[1];
}

=pod

=head3 window_left

    my $left = $main->window_left;

Return the main window position from the left of the screen.

=cut

sub window_left {
	( $_[0]->GetPositionXY )[0];
}

=pod

=head3 window_top

    my $top = $main->window_top;

Return the main window position from the top of the screen.

=cut

sub window_top {
	( $_[0]->GetPositionXY )[1];
}

=pod

=head2 Refresh Methods

Those methods refresh parts of Padre main window. The term C<refresh>
and the following methods are reserved for fast, blocking, real-time
updates to the GUI, implying rapid changes.

=head3 refresh

    $main->refresh;

Force refresh of all elements of Padre main window. (see below for
individual refresh methods)

=cut

sub refresh {
	my $self = shift;
	return if $self->no_refresh;

	# Freeze during the refresh
	my $guard   = $self->freezer;
	my $current = $self->current;

	$self->refresh_menubar($current);
	$self->refresh_toolbar($current);
	$self->refresh_status($current);
	$self->refresh_functions($current);

	my $notebook = $self->notebook;
	if ( $notebook->GetPageCount ) {
		my $id = $notebook->GetSelection;
		if ( defined $id and $id >= 0 ) {
			$notebook->GetPage($id)->SetFocus;
			$self->refresh_syntaxcheck;
		}
		$self->aui->GetPane('notebook')->PaneBorder(0);
	} else {
		$self->aui->GetPane('notebook')->PaneBorder(1);
	}

	# Update the GUI
	$self->aui->Update;

	return;
}

=pod

=head3 refresh_syntaxcheck

    $main->refresh_syntaxcheck;

Do a refresh of document syntax checking. This is a "rapid" change,
since actual syntax check is happening in the background.

=cut

sub refresh_syntaxcheck {
	my $self = shift;
	return if $self->no_refresh;
	return if not $self->menu->view->{show_syntaxcheck}->IsChecked;
	$self->syntax->on_timer( undef, 1 );
	return;
}

=pod

=head3 refresh_menu

    $main->refresh_menu;

Force a refresh of all menus. It can enable / disable menu entries
depending on current document or Padre internal state.

=cut

sub refresh_menu {
	my $self = shift;
	return if $self->no_refresh;
	$self->menu->refresh;
}

=pod

=head3 refresh_menubar

    $main->refresh_menubar;

Force a refresh of Padre's menubar.

=cut

sub refresh_menubar {
	my $self = shift;
	return if $self->no_refresh;
	$self->menu->refresh_top;
}

=pod

=head3 refresh_toolbar

    $main->refresh_toolbar;

Force a refresh of Padre's toolbar.

=cut

sub refresh_toolbar {
	my $self = shift;
	return if $self->no_refresh;
	my $toolbar = $self->GetToolBar;
	if ($toolbar) {
		$toolbar->refresh( $_[0] or $self->current );
	}
}

=pod

=head3 refresh_status

    $main->refresh_status;

Force a refresh of Padre's status bar.

=cut

sub refresh_status {
	my $self = shift;
	return if $self->no_refresh;
	$self->GetStatusBar->refresh( $_[0] or $self->current );
}

=pod

=head3 refresh_functions

    $main->refresh_functions;

Force a refresh of the function list on the right.

=cut

sub refresh_functions {

	# TODO now on every ui chnage (move of the mouse) we refresh
	# this even though that should not be necessary can that be
	# eliminated ?

	my $self = shift;
	return if $self->no_refresh;
	return unless $self->menu->view->{functions}->IsChecked;

	# Flush the list if there is no active document
	my $current   = _CURRENT(@_);
	my $document  = $current->document;
	my $functions = $self->functions;
	unless ($document) {
		$functions->DeleteAllItems;
		return;
	}

	my $config  = $self->config;
	my @methods = $document->get_functions;
	if ( $config->main_functions_order eq 'original' ) {

		# That should be the one we got from get_functions
	} elsif ( $config->main_functions_order eq 'alphabetical_private_last' ) {

		# ~ comes after \w
		@methods = map { tr/~/_/; $_ } ## no critic
			sort
			map { tr/_/~/; $_ }        ## no critic
			@methods;
	} else {

		# Alphabetical (aka 'abc')
		@methods = sort @methods;
	}

	if ( scalar(@methods) == scalar( @{ $self->{_methods} } ) ) {
		my $new = join ';', @methods;
		my $old = join ';', @{ $self->{_methods} };
		return if $old eq $new;
	}

	$functions->DeleteAllItems;
	foreach my $method ( reverse @methods ) {
		$functions->InsertStringItem( 0, $method );
	}
	$functions->SetColumnWidth( 0, Wx::wxLIST_AUTOSIZE );
	$self->{_methods} = \@methods;

	return;
}

=pod

=head2 Interface Rebuilding Methods

Those methods reconfigure Padre's main window in case of drastic changes
(locale, etc.)

=head3 change_style

    $main->change_style( $style, $private );

Apply C<$style> to Padre main window. C<$private> is a boolean true if
the style is located in user's private Padre directory.

=cut

sub change_style {
	my $self    = shift;
	my $name    = shift;
	my $private = shift;
	Padre::Wx::Editor::data( $name, $private );
	foreach my $editor ( $self->editors ) {
		$editor->padre_setup;
	}

	# Save editor style configuration
	$self->config->set( editor_style => $name );
	$self->config->write;
	return;
}

=pod

=head3 change_locale

    $main->change_locale( $locale );

Change Padre's locale to C<$locale>. This will update the GUI to reflect
the new locale.

=cut

sub change_locale {
	my $self = shift;
	my $name = shift;
	unless ( defined $name ) {
		$name = Padre::Locale::system_rfc4646();
	}
	Padre::Util::debug("Changing locale to '$name'");

	# Save the locale to the config
	$self->config->set( locale => $name );
	$self->config->write;

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

=pod

=head3 relocale

    $main->relocale;

The term and method C<relocale> is reserved for functionality intended
to run when the application wishes to change locale (and wishes to do so
without restarting).

Note at this point, that the new locale has already been fixed, and this
method is usually called by C<change_locale()>.

=cut

sub relocale {
	my $self = shift;

	# The find and replace dialogs don't support relocale
	# (and they might currently be visible) so get rid of them.
	if ( $self->has_find ) {
		$self->{find}->Destroy;
		delete $self->{find};
	}
	if ( $self->has_replace ) {
		$self->{replace}->Destroy;
		delete $self->{replace};
	}

	# Relocale the plugins
	$self->ide->plugin_manager->relocale;

	# The menu doesn't support relocale, replace it
	delete $self->{menu};
	$self->{menu} = Padre::Wx::Menubar->new($self);
	$self->SetMenuBar( $self->menu->wx );

	# The toolbar doesn't support relocale, replace it
	$self->rebuild_toolbar;

	# Update window manager captions
	$self->aui->relocale;
	$self->bottom->relocale;
	$self->right->relocale;
	$self->syntax->relocale;

	return;
}

=pod

=head3 reconfig

    $main->reconfig( $config );

The term and method "reconfig" is reserved for functionality intended to
run when Padre's underlying configuration is updated by an external
actor at run-time. The primary use cases for this method are when the
user configuration file is synced from a remote network location.

Note: This method is highly experimental and subject to change.

=cut

sub reconfig {
	my $self   = shift;
	my $config = shift;

	# Do everything inside a freeze
	my $guard = $self->freezer;

	# The biggest potential change is that the user may have a
	# different forced locale.
	# TODO - This could get subtle (we have to not only know
	# what the current locale is, but also if it was derived from
	# the system default or not)

	# Rebuild the toolbar if the lockinterface status has changed
	# TODO - Implement this

	# Show or hide all the main gui elements
	# TODO - Move this into the config ->apply logic
	$self->show_functions( $config->main_functions );
	$self->show_outline( $config->main_outline );
	$self->show_directory( $config->main_directory );
	$self->show_output( $config->main_output );
	$self->show_syntax( $config->main_syntaxcheck );

	# Finally refresh the menu to clean it up
	$self->menu->refresh;

	return 1;
}

=pod

=head3 rebuild_toolbar

    $main->rebuild_toolbar;

Destroy and rebuild the toolbar. This method is useful because the
toolbar is not really flexible, and most of the time it's better to
recreate it from scratch.

=cut

sub rebuild_toolbar {
	my $self = shift;

	my $toolbar = $self->GetToolBar;
	$toolbar->Destroy if $toolbar;

	$self->SetToolBar( Padre::Wx::ToolBar->new($self) );
	$self->GetToolBar->refresh;
	$self->GetToolBar->Realize;
	return 1;
}

#####################################################################

=pod

=head2 Tools and Dialogs

Those methods deal with the various panels that Padre provides, and
allow to show or hide them.

=head3 show_functions

    $main->show_functions( $visible );

Show the functions panel on the right if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_functions {
	my $self = shift;
	my $on = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	unless ( $on == $self->menu->view->{functions}->IsChecked ) {
		$self->menu->view->{functions}->Check($on);
	}
	$self->config->set( main_functions => $on );
	$self->config->write;

	if ($on) {
		$self->right->show( $self->functions );
	} else {
		$self->right->hide( $self->functions );
	}

	$self->aui->Update;
	$self->ide->save_config;

	return;
}

=pod

=head3 show_outline

    $main->show_outline( $visible );

Show the outline panel on the right if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_outline {
	my $self = shift;

	my $on = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	unless ( $on == $self->menu->view->{outline}->IsChecked ) {
		$self->menu->view->{outline}->Check($on);
	}
	$self->config->set( main_outline => $on );
	$self->config->write;

	if ($on) {
		my $outline = $self->outline;
		$self->right->show($outline);
		$outline->start unless $outline->running;
	} elsif ( $self->has_outline ) {
		my $outline = $self->outline;
		$self->right->hide($outline);
		$outline->stop if $outline->running;
	}

	$self->aui->Update;
	$self->ide->save_config;

	return;
}

=pod

=head3 show_directory

    $main->show_directory( $visible );

Show the directory panel on the right if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_directory {
	my $self = shift;

	my $on = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	unless ( $on == $self->menu->view->{directory}->IsChecked ) {
		$self->menu->view->{directory}->Check($on);
	}
	$self->config->set( main_directory => $on );
	$self->config->write;

	if ($on) {
		my $directory = $self->directory;
		$self->directory_panel->show($directory);
		$directory->refresh;
	} elsif ( $self->has_directory ) {
		$self->directory_panel->hide( $self->directory );
	}

	$self->aui->Update;
	$self->ide->save_config;

	return;
}

=pod

=head3 show_output

    $main->show_output( $visible );

Show the output panel at the bottom if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_output {
	my $self = shift;
	my $on = @_ ? $_[0] ? 1 : 0 : 1;
	unless ( $on == $self->menu->view->{output}->IsChecked ) {
		$self->menu->view->{output}->Check($on);
	}
	$self->config->set( main_output => $on );
	$self->config->write;

	if ($on) {
		$self->bottom->show( $self->output );
	} else {
		$self->bottom->hide( $self->output );
	}

	$self->aui->Update;
	$self->ide->save_config;

	return;
}

=pod

=head3 show_syntax

    $main->show_syntax( $visible );

Show the syntax panel at the bottom if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_syntax {
	my $self   = shift;
	my $syntax = $self->syntax;

	my $on = @_ ? $_[0] ? 1 : 0 : 1;
	unless ( $on == $self->menu->view->{show_syntaxcheck}->IsChecked ) {
		$self->menu->view->{show_syntaxcheck}->Check($on);
	}

	if ($on) {
		$self->bottom->show($syntax);
		$syntax->start unless $syntax->running;
	} else {
		$self->bottom->hide( $self->syntax );
		$syntax->stop if $syntax->running;
	}

	$self->aui->Update;
	$self->ide->save_config;

	return;
}

=pod

=head2 Introspection

The following methods allow to poke into Padre's internals.

=head3 current

    my $current = $main->current;

Creates a L<Padre::Current> object for the main window, giving you quick
and cacheing access to the current various whatevers.

See L<Padre::Current> for more information.

=cut

sub current {
	Padre::Current->new( main => $_[0] );
}

=pod

=head3 pageids

    my @ids = $main->pageids;

Return a list of all current tab ids (integers) within the notebook.

=cut

sub pageids {
	return ( 0 .. $_[0]->notebook->GetPageCount - 1 );
}

=pod

=head3 pages

    my @pages = $main->pages;

Return a list of all notebook tabs. Those are the real objects, not the
ids (see C<pageids()> above).

=cut

sub pages {
	my $notebook = $_[0]->notebook;
	return map { $notebook->GetPage($_) } $_[0]->pageids;
}

=pod

=head3 editors

    my @editors = $main->editors;

Return a list of all current editors. Those are the real objects, not
the ids (see C<pageids()> above).

Note: for now, this has the same meaning as C<pages()> (see above), but
this will change once we get project tabs or something else.

=cut

sub editors {
	my $notebook = $_[0]->notebook;
	return map { $notebook->GetPage($_) } $_[0]->pageids;
}

=pod

=head3 documents

    my @document = $main->documents;

Return a list of all current docunments, in the specific order
they are open in the notepad.

=cut

sub documents {
	return map { $_->{Document} } $_[0]->editors;
}

=pod

=head2 Process Execution

The following methods run an external command, for example to evaluate
current document.

=head3 on_run_command

    $main->on_run_command;

Prompt the user for a command to run, then run it with C<run_command()>
(see below).

Note: it probably needs to be combined with C<run_command()> itself.

=cut

sub on_run_command {
	my $main = shift;

	require Padre::Wx::History::TextEntryDialog;
	my $dialog = Padre::Wx::History::TextEntryDialog->new(
		$main,
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
	$main->run_command($command);
	return;
}

=pod

=head3 on_run_tests

    $main->on_run_tests;

Callback method, to run the project tests and harness them.

=cut

sub on_run_tests {
	my $self     = shift;
	my $document = $self->current->document;
	unless ($document) {
		return $self->error( Wx::gettext("No document open") );
	}

	# TODO probably should fetch the current project name
	my $filename = $document->filename;
	unless ($filename) {
		return $self->error( Wx::gettext("Current document has no filename") );
	}

	# Find the project
	my $project_dir = Padre::Util::get_project_dir($filename);
	unless ($project_dir) {
		return $self->error( Wx::gettext("Could not find project root") );
	}

	my $dir = Cwd::cwd;
	chdir $project_dir;
	$self->run_command("prove -b $project_dir/t");
	chdir $dir;
}

=pod

=head3 run_command

    $main->run_command( $command );

Run C<$command> and display the result in the output panel.

=cut

sub run_command {
	my $self = shift;
	my $cmd  = shift;

	# experimental
	# when this mode is used the Run menu options are not turned off
	# and the Run/Stop is not turned on as we currently cannot control
	# the external execution.
	my $config = $self->config;
	if ( $config->run_use_external_window ) {
		if ( Padre::Util::WIN32 ) {
			# '^' is the escape character in win32 command line
			# '"' is needed to escape spaces and other characters in paths
			$cmd =~ s/"/^/g;
			system "cmd.exe /C \"start $cmd\"";
		} else {
			system qq(xterm -e "$cmd; sleep 1000" &);
		}
		return;
	}

	# Disable access to the run menus
	$self->menu->run->disable;

	# Clear the error list
	$self->errorlist->clear;

	# Prepare the output window for the output
	$self->show_output(1);
	$self->output->Remove( 0, $self->output->GetLastPosition );

	# If this is the first time a command has been run,
	# set up the ProcessStream bindings.
	unless ($Wx::Perl::ProcessStream::VERSION) {
		require Wx::Perl::ProcessStream;
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDOUT(
			$self,
			sub {
				$_[1]->Skip(1);
				my $outpanel = $_[0]->output;
				$outpanel->style_neutral;
				$outpanel->AppendText( $_[1]->GetLine . "\n" );
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDERR(
			$self,
			sub {
				$_[1]->Skip(1);
				my $outpanel = $_[0]->output;
				$outpanel->style_bad;
				$outpanel->AppendText( $_[1]->GetLine . "\n" );

				$_[0]->errorlist->collect_data( $_[1]->GetLine );

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

	# TODO: It appears that Wx::Perl::ProcessStream's OpenProcess()
	# does not honour the docs, as we don't get to this cleanup code
	# even if we try to run a program that doesn't exist.
	unless ( $self->{command} ) {

		# Failed to start the command. Clean up.
		Wx::MessageBox(
			sprintf( Wx::gettext("Failed to start '%s' command"), $cmd ),
			Wx::gettext("Error"),
			Wx::wxOK, $self
		);
		$self->menu->run->enable;
	}

	return;
}

=pod

=head3 run_document

    $main->run_document( $debug )

Run current document. If C<$debug> is true, document will be run with
diagnostics and various debug options.

Note: this should really be somewhere else, but can stay here for now.

=cut

sub run_document {
	my $self     = shift;
	my $debug    = shift;
	my $document = $self->current->document;
	unless ($document) {
		return $self->error( Wx::gettext("No open document") );
	}

	# Apply the user's save-on-run policy
	# TODO: Make this code suck less
	unless ( $document->is_saved ) {
		my $config = $self->config;
		if ( $config->run_save eq 'same' ) {
			$self->on_save or return;
		} elsif ( $config->run_save eq 'all_files' ) {
			$self->on_save_all or return;
		} elsif ( $config->run_save eq 'all_buffer' ) {
			$self->on_save_all or return;
		}
	}

	unless ( $document->can('get_command') ) {
		return $self->error( Wx::gettext("No execution mode was defined for this document") );
	}

	my $cmd = eval { $document->get_command($debug) };
	if ($@) {
		chomp $@;
		$self->error($@);
		return;
	}
	if ($cmd) {
		if ( $document->pre_process ) {
			$self->run_command($cmd);
		} else {
			$self->error( $document->errstr );
		}
	}
	return;
}

=pod

=head3 debug_perl

    $main->debug_perl;

Run current document under perl debugger. An error is reported if
current is not a Perl document.

=cut

sub debug_perl {
	my $self     = shift;
	my $document = $self->current->document;
	unless ( $document->isa('Perl::Document::Perl') ) {
		return $self->error( Wx::gettext("Not a Perl document") );
	}

	# Check the file name
	my $filename = $document->filename;

	#	unless ( $filename =~ /\.pl$/i ) {
	#		return $self->error(Wx::gettext("Only .pl files can be executed"));
	#	}

	# Apply the user's save-on-run policy
	# TODO: Make this code suck less
	my $config = $self->config;
	if ( $config->run_save eq 'same' ) {
		$self->on_save;
	} elsif ( $config->run_save eq 'all_files' ) {
		$self->on_save_all;
	} elsif ( $config->run_save eq 'all_buffer' ) {
		$self->on_save_all;
	}

	# Set up the debugger
	my $host = 'localhost';
	my $port = 12345;

	# $self->_setup_debugger($host, $port);
	local $ENV{PERLDB_OPTS} = "RemotePort=$host:$port";

	# Run with the same Perl that launched Padre
	my $perl = Padre::Perl::perl();
	$self->run_command(qq["$perl" -d "$filename"]);

}

=pod

=head2 Session Support

Those methods deal with Padre sessions. A session is a set of files /
tabs opened, with the position within the files saved, as well as the
document that has the focus.

=head3 capture_session

    my @session = $main->capture_session;

Capture list of opened files, with information. Return a list of
C<Padre::DB::SessionFile> objects.

=cut

sub capture_session {
	my $self     = shift;
	my @session  = ();
	my $notebook = $self->notebook;
	my $current  = $self->current->filename;
	foreach my $pageid ( $self->pageids ) {
		next unless defined $pageid;
		my $editor   = $notebook->GetPage($pageid);
		my $document = $editor->{Document} or next;
		my $file     = $editor->{Document}->filename;
		next unless defined $file;
		my $position = $editor->GetCurrentPos;
		my $focus    = ( defined $current and $current eq $file ) ? 1 : 0;
		my $obj      = Padre::DB::SessionFile->new(
			file     => $file,
			position => $position,
			focus    => $focus,
		);
		push @session, $obj;
	}

	return @session;
}

=pod

=head3 open_session

    $main->open_session( $session );

Try to close all files, then open all files referenced in the given
C<$session> (a C<Padre::DB::Session> object). No return value.

=cut

sub open_session {
	my ( $self, $session ) = @_;

	# prevent redrawing until we're done
	$self->Freeze;

	# Close all files
	$self->close_all;

	# get list of files in the session
	my @files = $session->files;
	return unless @files;

	# opening documents
	my $focus    = undef;
	my $notebook = $self->notebook;
	foreach my $document (@files) {
		Padre::Util::debug( "Opening '" . $document->file . "' for $document" );
		my $filename = $document->file;
		next unless -f $filename;
		my $id = $self->setup_editor($filename);
		next unless $id; # documents already opened have undef $id
		Padre::Util::debug("Setting focus on $filename");
		$focus = $id if $document->focus;
		$notebook->GetPage($id)->goto_pos_centerize( $document->position );
	}
	$self->on_nth_pane($focus) if defined $focus;

	# now we can redraw
	$self->Thaw;
}

=pod

=head3 save_session

    $main->save_session( $session, @session );

Try to save C<@session> files (C<Padre::DB::SessionFile> objects, such
as what is returned by C<capture_session()> - see above) to database,
associated to C<$session>. Note that C<$session> should already exist.

=cut

sub save_session {
	my ( $self, $session, @session ) = @_;

	Padre::DB->begin;
	foreach my $file (@session) {
		$file->{session} = $session->id;
		$file->insert;
	}
	Padre::DB->commit;
}

=pod

=head2 User Interaction

Various methods to help send information to user.

=head3 message

    $main->message( $msg, $title );

Open a dialog box with C<$msg> as main text and C<$title> (title
defaults to C<Message>). There's only one OK button. No return value.

=cut

sub message {
	my $self    = shift;
	my $message = shift;
	my $title   = shift || Wx::gettext('Message');
	Wx::MessageBox( $message, $title, Wx::wxOK | Wx::wxCENTRE, $self );
	return;
}

=pod

=head3 error

    $main->error( $msg );

Open an error dialog box with C<$msg> as main text. There's only one OK
button. No return value.

=cut

sub error {
	$_[0]->message( $_[1], Wx::gettext('Error') );
}

=pod

=head3 prompt

    my $value = $main->prompt( $title, $subtitle, $key );

Prompt user with a dialog box about the value that C<$key> should have.
Return this value, or undef if user clicked C<cancel>.

=cut

sub prompt {
	my $self     = shift;
	my $title    = shift || "Prompt";
	my $subtitle = shift || "Subtitle";
	my $key      = shift || "GENERIC";

	require Padre::Wx::History::TextEntryDialog;
	my $dialog = Padre::Wx::History::TextEntryDialog->new(
		$self, $title, $subtitle, $key,
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $value = $dialog->GetValue;
	$dialog->Destroy;
	return $value;
}

=pod

=head2 Search and Replace

These methods provide the highest level abstraction for entry into the various
search and replace functions and dialogs.

However, they still represent abstract logic and should NOT be tied directly to
keystroke or menu events.

=head2 search_next

  # Next match for a new search
  $main->search_next( $search );
  
  # Next match on current search (or show Find dialog if none)
  $main->search_next;

Find the next match for the current search, or spawn the Find dialog.

If no files are open, silently do nothing (don't even remember the new search)

=cut

sub search_next {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	if ( _INSTANCE($_[0], 'Padre::Search') ) {
		$self->{search} = shift;
	} elsif ( @_ ) {
		die("Invalid argument to search_next");
	}
	if ( $self->search ) {
		$self->search->search_next($editor);
	} else {
		$self->find->find;
	}
}

=pod

=head2 search_previous

  # Previous match for a new search
  $main->search_previous( $search );
  
  # Previous match on current search (or show Find dialog if none)
  $main->search_previous;

Find the previous match for the current search, or spawn the Find dialog.

If no files are open, do nothing

=cut

sub search_previous {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	if ( _INSTANCE($_[0], 'Padre::Search') ) {
		$self->{search} = shift;
	} elsif ( @_ ) {
		die("Invalid argument to search_previous");
	}
	if ( $self->search ) {
		$self->search->search_previous($editor);
	} else {
		$self->find->find;
	}
}

=pod

=head2 General Events

Those methods are the various callbacks registered in the menus or
whatever widgets Padre has.

=head3 on_brace_matching

    $main->on_brace_matching;

Jump to brace matching current the one at current position.

=cut

sub on_brace_matching {
	my $self = shift;
	my $page = $self->current->editor;
	my $pos1 = $page->GetCurrentPos;
	my $pos2 = $page->BraceMatch($pos1);
	if ( $pos2 == -1 ) { #Wx::wxSTC_INVALID_POSITION
		if ( $pos1 > 0 ) {
			$pos1--;
			$pos2 = $page->BraceMatch($pos1);
		}
	}

	if ( $pos2 != -1 ) { #Wx::wxSTC_INVALID_POSITION
		$page->GotoPos($pos2);
	}

	# TODO: or any nearby position.

	return;
}

=pod

=head3 on_comment_toggle_block

    $main->on_comment_toggle_block;

Un/comment selected lines, depending on their current state.

=cut

sub on_comment_toggle_block {
	my $self     = shift;
	my $current  = $self->current;
	my $editor   = $current->editor;
	my $document = $current->document;
	my $begin    = $editor->LineFromPosition( $editor->GetSelectionStart );
	my $end      = $editor->LineFromPosition( $editor->GetSelectionEnd );
	my $string   = $document->comment_lines_str;
	return unless defined $string;
	$editor->comment_toggle_lines( $begin, $end, $string );
	return;
}

=pod

=head3 on_comment_out_block

    $main->on_comment_out_block;

Comment out selected lines unilateraly.

=cut

sub on_comment_out_block {
	my $self     = shift;
	my $current  = $self->current;
	my $editor   = $current->editor;
	my $document = $current->document;
	my $begin    = $editor->LineFromPosition( $editor->GetSelectionStart );
	my $end      = $editor->LineFromPosition( $editor->GetSelectionEnd );
	my $string   = $document->comment_lines_str;
	return unless defined $string;
	$editor->comment_lines( $begin, $end, $string );
	return;
}

=pod

=head3 on_uncomment_block

    $main->on_uncomment_block;

Uncomment selected lines unilateraly.

=cut

sub on_uncomment_block {
	my $self     = shift;
	my $current  = $self->current;
	my $editor   = $current->editor;
	my $document = $current->document;
	my $begin    = $editor->LineFromPosition( $editor->GetSelectionStart );
	my $end      = $editor->LineFromPosition( $editor->GetSelectionEnd );
	my $string   = $document->comment_lines_str;
	return unless defined $string;
	$editor->uncomment_lines( $begin, $end, $string );
	return;
}

=pod

=head3 on_autocompletion

    $main->on_autocompletition;

Try to autocomplete current word being typed, depending on
document type.

=cut

sub on_autocompletition {
	my $self = shift;
	my $document = $self->current->document or return;
	my ( $length, @words ) = $document->autocomplete;
	if ( $length =~ /\D/ ) {
		Wx::MessageBox(
			$length,
			Wx::gettext("Autocompletion error"),
			Wx::wxOK,
		);
	}
	if (@words) {
		$document->editor->AutoCompShow( $length, join " ", @words );
	}
	return;
}

=pod

=head3 on_goto

    $main->on_goto;

Prompt user for a line, and jump to this line in current document.

=cut

sub on_goto {
	my $self = shift;

	my $editor      = $self->current->editor;
	my $max         = $editor->GetLineCount;
	my $line_number = $self->prompt(
		sprintf( Wx::gettext("Line number between (1-%s):"), $max ),
		Wx::gettext("Go to line number"),
		"GOTO_LINE_NUMBER"
	);
	return if not defined $line_number or $line_number !~ /^\d+$/;

	$line_number = $max if $line_number > $max;
	$line_number--;
	$editor->goto_line_centerize($line_number);

	return;
}

=pod

=head3 on_close_window

    $main->on_close_window( $event );

Callback when window is about to be closed. This is our last chance to
veto the C<$event> close, eg when some files are not yet saved.

If close is confirmed, save config to disk. Also, capture current
session to be able to restore it next time if user set Padre to open
last session on startup. Clean up all Task Manager's tasks.

=cut

sub on_close_window {
	my $self   = shift;
	my $event  = shift;
	my $ide    = $self->ide;
	my $config = $ide->config;

	Padre::Util::debug("on_close_window");

	# Capture the current session, before we start the interactive
	# part of the shutdown which will mess it up. Don't save it to
	# the config yet, because we haven't committed to the shutdown
	# until we get past the interactive phase.
	my @session = $self->capture_session;

	Padre::Util::debug("went over list of files");

	# Check that all files have been saved
	if ( $event->CanVeto ) {
		if ( $config->main_startup eq 'same' ) {

			# Save the files, but don't close
			my $saved = $self->on_save_all;
			unless ($saved) {

				# They cancelled at some point
				$event->Veto;
				return;
			}
		} else {
			my $closed = $self->close_all;
			unless ($closed) {

				# They cancelled at some point
				$event->Veto;
				return;
			}
		}
	}

	Padre::Util::debug("Files saved (or not), hiding window");

	# Immediately hide the window so that the user
	# perceives the application as closing faster.
	# This knocks about quarter of a second off the speed
	# at which Padre appears to close.
	$self->Show(0);

	# Save the window geometry
	#$config->set( main_auilayout => $self->aui->SavePerspective );
	$config->set( main_maximized => $self->IsMaximized ? 1 : 0 );

	# Don't save the maximized window size
	unless ( $self->IsMaximized ) {
		my ( $main_width, $main_height ) = $self->GetSizeWH;
		my ( $main_left,  $main_top )    = $self->GetPositionXY;
		$config->set( main_width  => $main_width );
		$config->set( main_height => $main_height );
		$config->set( main_left   => $main_left );
		$config->set( main_top    => $main_top );
	}

	# Clean up our secondary windows
	if ( $self->has_about ) {
		$self->about->Destroy;
	}
	if ( $self->{help} ) {
		$self->{help}->Destroy;
	}

	# Shut down all the plugins before saving the configuration
	# so that plugins have a change to save their configuration.
	$ide->plugin_manager->shutdown;
	Padre::Util::debug("After plugin manager shutdown");

	# Write the session to the database
	Padre::DB->begin;
	my $session = Padre::DB::Session->last_padre_session;
	Padre::DB::SessionFile->delete( 'where session = ?', $session->id );
	Padre::DB->commit;
	$self->save_session( $session, @session );

	# Write the configuration to disk
	$ide->save_config;
	$event->Skip;

	Padre::Util::debug("Tell TaskManager to cleanup");

	# Stop all Task Manager's worker threads
	$self->ide->task_manager->cleanup;

	Padre::Util::debug("Closing Padre");

	return;
}

=pod

=head3 on_split_window

    $main->on_split_window;

Open a new editor with the same current document. No return value.

=cut

sub on_split_window {
	my $self     = shift;
	my $current  = $self->current;
	my $notebook = $current->notebook;
	my $editor   = $current->editor;
	my $title    = $current->title;
	my $file     = $current->filename or return;
	my $pointer  = $editor->GetDocPointer;
	$editor->AddRefDocument($pointer);

	my $_editor = Padre::Wx::Editor->new( $self->notebook );
	$_editor->{Document} = $editor->{Document};
	$_editor->padre_setup;
	$_editor->SetDocPointer($pointer);
	$_editor->set_preferences;

	$self->ide->plugin_manager->editor_enable($_editor);
	$self->create_tab( $_editor, " $title" );

	return;
}

=pod

=head3 setup_editors

    $main->setup_editors( @files );

Setup (new) tabs for C<@files>, and update the GUI. If C<@files> is undef, open
an empty document.

=cut

sub setup_editors {
	my $self  = shift;
	my @files = @_;
	Padre::Util::debug("setup_editors @files");
	SCOPE: {

		# Lock both Perl and Wx-level updates
		local $self->{_no_refresh} = 1;
		my $guard = $self->freezer;

		# If and only if there is only one current file,
		# and it is unused, close it. This is a somewhat
		# subtle interface DWIM trick, but it's one that
		# clearly looks wrong when we DON'T do it.
		if ( $self->notebook->GetPageCount == 1 ) {
			if ( $self->current->document->is_unused ) {
				$self->on_close($self);
			}
		}

		if (@files) {
			foreach my $f (@files) {
				$self->setup_editor($f);
			}
		} else {
			$self->setup_editor;
		}
	}

	# Update the menus AFTER the initial GUI update,
	# because it makes file loading LOOK faster.
	# Do the menu/etc refresh in the time it takes the
	# user to actually perceive the file has been opened.
	$self->refresh;

	return;
}

=pod

=head3 on_new

    $main->on_new;

Create a new empty tab. No return value.

=cut

sub on_new {
	my $self = shift;
	$self->Freeze;
	$self->setup_editor;
	$self->Thaw;
	$self->refresh;
	return;
}

=pod

=head3 setup_editor

    $main->setup_editor( $file );

Setup a new tab / buffer and open C<$file>, then update the GUI. Recycle
current buffer if there's only one empty tab currently opened. If C<$file> is
already opened, focus on the tab displaying it. Finally, if C<$file> does not
exist, create an empty file before opening it.

=cut

sub setup_editor {
	my ( $self, $file ) = @_;
	my $config = $self->config;

	Padre::Util::debug( "setup_editor called for '" . ( $file || '' ) . "'" );
	# These need to be TWO if's, because Cwd::realpath returns undef when opening an non-existent file!
	if ($file) {
		$file = Cwd::realpath($file); # get absolute path
	}
	if ($file) {
		my $id = $self->find_editor_of_file($file);
		if ( defined $id ) {
			$self->on_nth_pane($id);
			return;
		}

		# if file does not exist, create it so that future access
		# (such as size checking) won't warn / blow up padre
		if ( not -f $file ) {
			open my $fh, '>', $file;
			close $fh;
		}
		if ( -s $file > $config->editor_file_size_limit ) {
			return $self->error(
				sprintf(
					Wx::gettext(
						"Cannot open %s as it is over the arbitrary file size limit of Padre which is currently %s"),
					$file,
					$config->editor_file_size_limit
				)
			);
		}
	}

	local $self->{_no_refresh} = 1;

	my $doc = Padre::Document->new(
		filename => $file,
	);

	$file ||= ''; #to avoid warnings
	if ( $doc->errstr ) {
		warn $doc->errstr . " when trying to open '$file'";
		return;
	}

	Padre::Util::debug("Document created for '$file'");

	my $editor = Padre::Wx::Editor->new( $self->notebook );
	$editor->{Document} = $doc;
	$doc->set_editor($editor);
	$editor->configure_editor($doc);

	$self->ide->plugin_manager->editor_enable($editor);

	my $title = $editor->{Document}->get_title;

	$editor->set_preferences;

	if ( $config->main_syntaxcheck ) {
		if ( $editor->GetMarginWidth(1) == 0 ) {
			$editor->SetMarginType( 1, Wx::wxSTC_MARGIN_SYMBOL ); # margin number 1 for symbols
			$editor->SetMarginWidth( 1, 16 );                     # set margin 1 16 px wide
		}
	}

	if ( !$doc->is_new ) {
		Padre::Util::debug( "Adding new file to history: " . $doc->filename );
		Padre::DB::History->create(
			type => 'files',
			name => $doc->filename,
		);
		$self->menu->file->update_recentfiles;
	} else {
		$doc->{project_dir} =
			  $self->current->document
			? $self->current->document->project_dir
			: $self->ide->config->default_projects_directory;
	}

	my $id = $self->create_tab( $editor, $title );
	$self->notebook->GetPage($id)->SetFocus;

	# no need to call this here as set_preferences already calls padre_setup.
	#$editor->padre_setup;

	Wx::Event::EVT_MOTION( $editor, \&Padre::Wx::Editor::on_mouse_motion );

	$doc->restore_cursor_position;

	return $id;
}

=pod

=head3 create_tab

    my $tab = $main->create_tab;

Create a new tab in the notebook, and return its id (an integer).

=cut

sub create_tab {
	my ( $self, $editor, $title ) = @_;
	$self->notebook->AddPage( $editor, $title, 1 );
	$editor->SetFocus;
	my $id = $self->notebook->GetSelection;
	$self->refresh;
	return $id;
}

=pod

=head3 on_open_selection

    $main->on_open_selection;

Try to open current selection in a new tab. Different combinations are
tried in order: as full path, as path relative to cwd (where the editor
was started), as path to relative to where the current file is, if we
are in a perl file or perl environment also try if the thing might be a
name of a module and try to open it locally or from @INC.

No return value.

=cut

sub on_open_selection {
	my $self    = shift;
	my $current = $self->current;
	return unless $current->editor;
	my $text = $current->text;

	# get selection, ask for it if needed
	unless ( length $text ) {
		my $dialog = Wx::TextEntryDialog->new(
			$self,
			Wx::gettext("Nothing selected. Enter what should be opened:"),
			Wx::gettext("Open selection"),
			''
		);
		return if $dialog->ShowModal == Wx::wxID_CANCEL;

		$text = $dialog->GetValue;
		$dialog->Destroy;
		return unless length $text;
	}

	#remove leading and trailing whitespace or newlines
	#atm, we assume you are opening _one_ file, so newlines in the middle are significant
	$text =~ s/^[\s\n]*(.*?)[\s\n]*$/$1/;

	my @files;
	if ( File::Spec->file_name_is_absolute($text) and -e $text ) {
		push @files, $text;
	} else {

		# Try relative to the dir we started in?
		SCOPE: {
			my $filename = File::Spec->catfile(
				$self->ide->{original_cwd},
				$text,
			);
			if ( -e $filename ) {
				push @files, $filename;
			}
		}

		# Try relative to the current file
		if ( $current->filename ) {
			my $filename = File::Spec->catfile(
				File::Basename::dirname( $current->filename ),
				$text,
			);
			if ( -e $filename ) {
				push @files, $filename;
			}
		}
	}
	unless (@files) { # TODO: and if we are in a Perl environment
		my $module = $text;
		$module =~ s{::}{/}g;
		$module .= ".pm";
		my $filename = File::Spec->catfile(
			$self->ide->{original_cwd},
			$module,
		);
		if ( -e $filename ) {
			push @files, $filename;
		} else {

			# relative to the project dir
			my $filename = File::Spec->catfile(
				$self->current->document->project_dir,
				'lib',
				$module,
			);
			if ( -e $filename ) {
				push @files, $filename;
			}

			# TODO: it should not be our @INC but the @INC of the perl used for
			# script execution
			foreach my $path (@INC) {
				my $filename = File::Spec->catfile( $path, $module );
				if ( -e $filename ) {
					push @files, $filename;

					#last;
				}
			}
		}
	}

	unless (@files) {
		Wx::MessageBox(
			sprintf( Wx::gettext("Could not find file '%s'"), $text ),
			Wx::gettext("Open Selection"),
			Wx::wxOK,
			$self,
		);
		return;
	}

	# eliminate duplicates
	my %seen;
	@files = grep { !$seen{$_}++ } @files;

	require Wx::Perl::Dialog::Simple;
	my $file = Wx::Perl::Dialog::Simple::single_choice( choices => \@files );

	if ($file) {
		$self->setup_editors($file);
	}

	return;
}

=pod

=head3 on_open_all_recent_files

    $main->on_open_all_recent_files;

Try to open all recent files within Padre. No return value.

=cut

sub on_open_all_recent_files {
	my $files = Padre::DB::History->recent('files');

	# debatable: "reverse" keeps order in "recent files" submenu
	# but editor tab ordering may "feel" wrong
	$_[0]->setup_editors( reverse @$files );
}

=pod

=head3 on_open

    $main->on_open;

Prompt user for file(s) to open, and open them as new tabs. No
return value.

=cut

sub on_open {
	my $self     = shift;
	my $filename = $self->current->filename;
	if ($filename) {
		$self->{cwd} = File::Basename::dirname($filename);
	}
	$self->_open_file_dialog;

	return;
}

sub _open_file_dialog {
	my $self = shift;

	# http://docs.wxwidgets.org/stable/wx_wxfiledialog.html:
	# "It must be noted that wildcard support in the native Motif file dialog is quite
	# limited: only one alternative is supported, and it is displayed without
	# the descriptive text."
	# But I don't think Wx + Motif is in use nowadays
	my $wildcards = join(
		'|',
		Wx::gettext("JavaScript Files"), "*.js;*.JS",
		Wx::gettext("Perl Files"),       "*.pm;*.PM;*.pl;*.PL",
		Wx::gettext("PHP Files"),        "*.php;*.php5;*.PHP",
		Wx::gettext("Python Files"),     "*.py;*.PY",
		Wx::gettext("Ruby Files"),       "*.rb;*.RB",
		Wx::gettext("SQL Files"),        "*.slq;*.SQL",
		Wx::gettext("Text Files"),       "*.txt;*.TXT;*.yml;*.conf;*.ini;*.INI",
		Wx::gettext("Web Files"),        "*.html;*.HTML;*.htm;*.HTM;*.css;*.CSS",
	);
	$wildcards =
		Padre::Constant::WIN32
		? Wx::gettext("All Files") . "|*.*|" . $wildcards
		: Wx::gettext("All Files") . "|*|" . $wildcards;
	my $dialog = Wx::FileDialog->new(
		$self,
		Wx::gettext("Open File"),
		$self->cwd,
		"",
		$wildcards,
		Wx::wxFD_MULTIPLE,
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my @filenames = $dialog->GetFilenames;
	$self->{cwd} = $dialog->GetDirectory;

	my @files = map { File::Spec->catfile( $self->cwd, $_ ) } @filenames;
	$self->setup_editors(@files);

	return;
}

sub on_open_example {
	my $self = shift;
	$self->{cwd} = Padre::Util::sharedir('examples');
	$self->_open_file_dialog;

	return;
}


=pod

=head3 on_reload_file

    $main->on_reload_file;

Try to reload current file from disk. Display an error if something went wrong.
No return value.

=cut

sub on_reload_file {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $editor   = $document->editor;

	$document->store_cursor_position;
	if ( $document->reload ) {
		$document->editor->configure_editor($document);
		$document->restore_cursor_position;
	} else {
		$self->error(
			sprintf(
				Wx::gettext("Could not reload file: %s"),
				$document->errstr
			)
		);
	}
	return;
}

=pod

=head3 on_save_as

    my $was_saved = $main->on_save_as;

Prompt user for a new filename to save current document, and save it.
Returns true if saved, false if cancelled.

=cut

sub on_save_as {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $current  = $document->filename;
	if ( defined $current ) {
		$self->{cwd} = File::Basename::dirname($current);
	} elsif ( defined $document->project_dir ) {
		$self->{cwd} = $document->project_dir;
	}
	while (1) {
		my $dialog = Wx::FileDialog->new(
			$self,
			Wx::gettext("Save file as..."),
			$self->{cwd},
			"",
			"*.*",
			Wx::wxFD_SAVE,
		);
		if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
			return;
		}

		# GetPath will return the typed in string
		# for a file path to be saved to.
		# now we need to work out if we use GetPath
		# or concatinate the two values used.

		#my $filename = $dialog->GetFilename;
		#print "FileName: $filename\n";
		#my $dir = $dialog->GetDirectory;
		#print "Directory: $dir\n";
		#print "Path: " . $dialog->GetPath  . "\n";
		$self->{cwd} = $dialog->GetDirectory;
		my $saveto = $dialog->GetPath;

		#my $path = File::Spec->catfile( $self->cwd, $filename );
		my $path = File::Spec->catfile($saveto);
		if ( -e $path ) {
			my $response = Wx::MessageBox(
				Wx::gettext("File already exists. Overwrite it?"),
				Wx::gettext("Exist"),
				Wx::wxYES_NO,
				$self,
			);
			if ( $response == Wx::wxYES ) {
				$document->_set_filename($path);
				$document->save_file;
				$document->set_newline_type(Padre::Constant::NEWLINE);
				last;
			}
		} else {
			$document->_set_filename($path);
			$document->save_file;
			$document->set_newline_type(Padre::Constant::NEWLINE);
			delete $document->{project_dir};
			last;
		}
	}
	my $pageid = $self->notebook->GetSelection;
	$self->_save_buffer($pageid);

	$document->set_mimetype( $document->guess_mimetype );
	$document->editor->padre_setup;
	$document->rebless;

	Padre::DB::History->create(
		type => 'files',
		name => $document->filename,
	);
	$self->menu->file->update_recentfiles;

	$self->refresh;

	return 1;
}

=pod

=head3 on_save

    my $success = $main->on_save;

Try to save current document. Prompt user for a filename if document was
new (see C<on_save_as()> above). Return true if document has been saved,
false otherwise.

=cut

sub on_save {
	my $self = shift;
	my $document = shift || $self->current->document;
	return unless $document;

	#print $document->filename, "\n";

	my $pageid = $self->find_id_of_editor( $document->editor );
	if ( $document->is_new ) {

		# move focus to document to be saved
		$self->on_nth_pane($pageid);
		return $self->on_save_as;
	} elsif ( $document->is_modified ) {
		return $self->_save_buffer($pageid);
	}

	return;
}

=pod

=head3 on_save_all

    my $success = $main->on_save_all;

Try to save all opened documents. Return true if all documents were
saved, false otherwise.

=cut

sub on_save_all {
	my $self = shift;
	foreach my $id ( $self->pageids ) {
		my $editor = $self->notebook->GetPage($id) or next;
		my $doc = $editor->{Document}; # TODO no accessor for document?
		if ( $doc->is_modified ) {
			$self->on_save($doc) or return 0;
		}
	}
	return 1;
}

=pod

=head3 _save_buffer

    my $success = $main->_save_buffer( $id );

Try to save buffer in tab C<$id>. This is the method used underneath by
all C<on_save_*()> methods. It will check if document has been updated
out of Padre before saving, and report an error if something went wrong.
Return true if buffer was saved, false otherwise.

=cut

sub _save_buffer {
	my ( $self, $id ) = @_;

	my $page = $self->notebook->GetPage($id);
	my $doc = $page->{Document} or return;

	if ( $doc->has_changed_on_disk ) {
		my $ret = Wx::MessageBox(
			Wx::gettext("File changed on disk since last saved. Do you want to overwrite it?"),
			$doc->filename || Wx::gettext("File not in sync"),
			Wx::wxYES_NO | Wx::wxCENTRE,
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

	$page->SetSavePoint;
	$self->refresh;

	return 1;
}

=pod

=head3 on_close

    $main->on_close( $event );

Handler when there is a close C<$event>. Veto it if it's from the aui
notebook, since wx will try to close the tab no matter what. Otherwise,
close current tab. No return value.

=cut

sub on_close {
	my $self  = shift;
	my $event = shift;

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

=pod

=head3 close

    my $success = $main->close( $id );

Request to close document in tab C<$id>, or current one if no C<$id>
provided. Return true if closed, false otherwise.

=cut

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
			$self->on_save($doc);
		} elsif ( $ret == Wx::wxNO ) {

			# just close it
		} else {

			# Wx::wxCANCEL, or when clicking on [x]
			return 0;
		}
	}

	$doc->store_cursor_position;
	$doc->remove_tempfile if $doc->tempfile;

	$self->notebook->DeletePage($id);

	$self->syntax->clear;
	if ( $self->has_outline ) {
		$self->outline->clear;
	}
	if ( $self->has_directory ) {
		$self->directory->clear;
	}

	# Remove the entry from the Window menu
	$self->menu->window->refresh( $self->current );

	return 1;
}

=pod

=head3 close_all

    my $success = $main->close_all( $skip );

Try to close all documents. If C<$skip> is specified (an integer), don't
close the tab with this id. Return true upon success, false otherwise.

=cut

sub close_all {
	my $self  = shift;
	my $skip  = shift;
	my $guard = $self->freezer;
	foreach my $id ( reverse $self->pageids ) {
		if ( defined $skip and $skip == $id ) {
			next;
		}
		$self->close($id) or return 0;
	}
	$self->refresh;
	return 1;
}

=pod

=head3 close_where

    # Close all files in current project
    my $project = Padre::Current->document->project_dir;
    my $success = $main->close_where( sub {
        $_[0]->project_dir eq $project
    } );

The C<close_where> method is a programatically enhanceable mass-close
tool. It takes a subroutine as a parameter and calls that subroutine
for each currently open document, passing the document as the first
parameter.

Any documents that return true will be closed.

=cut

sub close_where {
	my $self     = shift;
	my $where    = shift;
	my $notebook = $self->notebook;
	my $guard    = $self->freezer;
	foreach my $id ( reverse $self->pageids ) {
		if ( $where->( $notebook->GetPage($id)->{Document} ) ) {
			$self->close($id) or return 0;
		}
	}
	$self->refresh;
	return 1;
}

=pod

=head3 on_nth_path

    $main->on_nth_pane( $id );

Put focus on tab C<$id> in the notebook. Return true upon success, false
otherwise.

=cut

sub on_nth_pane {
	my $self = shift;
	my $id   = shift;
	my $page = $self->notebook->GetPage($id);
	if ($page) {
		$self->notebook->SetSelection($id);
		$self->refresh_status( $self->current );
		$page->{Document}->set_indentation_style(); # TODO: encapsulation?
		return 1;
	}
	return;
}

=pod

=head3 on_next_pane

    $main->on_next_pane;

Put focus on tab next to current document. Currently, only left to right
order is supported, but later on it can be extended to follow a last
seen order.

No return value.

=cut

sub on_next_pane {
	my $self  = shift;
	my $count = $self->notebook->GetPageCount or return;
	my $id    = $self->notebook->GetSelection;
	if ( $id + 1 < $count ) {
		$self->on_nth_pane( $id + 1 );
	} else {
		$self->on_nth_pane(0);
	}
	return;
}

=pod

=head3 on_prev_pane

    $main->on_prev_pane;

Put focus on tab previous to current document. Currently, only right to
left order is supported, but later on it can be extended to follow a
reverse last seen order.

No return value.

=cut

sub on_prev_pane {
	my $self  = shift;
	my $count = $self->notebook->GetPageCount or return;
	my $id    = $self->notebook->GetSelection;
	if ($id) {
		$self->on_nth_pane( $id - 1 );
	} else {
		$self->on_nth_pane( $count - 1 );
	}
	return;
}

=pod

=head3 on_diff

    $main->on_diff;

Run C<Text::Diff> between current document and its last saved content on
disk. This allow to see what has changed before saving. Display the
differences in the output pane.

=cut

sub on_diff {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $text     = $document->text_get;
	my $file     = $document->filename;
	unless ($file) {
		return $self->error( Wx::gettext("Cannot diff if file was never saved") );
	}

	my $external_diff = $self->config->external_diff_tool;
	if ($external_diff) {
		my $dir = File::Temp::tempdir( CLEANUP => 1 );
		my $filename = File::Spec->catdir( $dir, 'IN_EDITOR' . File::Basename::basename($file) );
		if ( open my $fh, '>', $filename ) {
			print $fh $text;
			CORE::close($fh);
			system( $external_diff, $file, $filename );
		} else {
			$self->error($!);
		}

		# save current version in a temp directory
		# run the external diff on the original and the launch the
	} else {
		require Text::Diff;
		my $diff = Text::Diff::diff( $file, \$text );
		unless ($diff) {
			$diff = Wx::gettext("There are no differences\n");
		}

		$self->show_output(1);
		$self->output->clear;
		$self->output->AppendText($diff);
	}

	return;
}

=pod

=head3 on_join_lines

    $main->on_join_lines;

Join current line with next one (a-la vi with Ctrl+J). No return value.

=cut

sub on_join_lines {
	my $self = shift;
	my $page = $self->current->editor;

	# find positions
	my $pos1 = $page->GetCurrentPos;
	my $line = $page->LineFromPosition($pos1);
	my $pos2 = $page->PositionFromLine( $line + 1 );

	# Remove leading spaces/tabs from the second line
	my $code = $page->GetLine( $page->LineFromPosition($pos2) );
	$code =~ s/^\s+//;
	$code =~ s/\n$//;
	$page->SetTargetStart($pos2);
	$page->SetTargetEnd( $page->GetLineEndPosition( $line + 1 ) );
	$page->ReplaceTarget($code);

	# mark target & join lines
	$page->SetTargetStart($pos1);
	$page->SetTargetEnd($pos2);
	$page->LinesJoin;
}

=pod

=head2 Preferences and toggle methods

Those methods allow to change Padre's preferences.

=head3 zoom

    $main->zoom( $factor );

Apply zoom C<$factor> to Padre's documents. Factor can be either
positive or negative.

=cut

sub zoom {
	my $self = shift;
	my $zoom = $self->current->editor->GetZoom + shift;
	foreach my $page ( $self->editors ) {
		$page->SetZoom($zoom);
	}
}

=pod

=head3 on_preferences

    $main->on_preferences;

Open Padre's preferences dialog. No return value.

=cut

sub on_preferences {
	my $self = shift;

	require Padre::MimeTypes;
	my %old_highlighters = Padre::MimeTypes->get_current_highlighters;

	require Padre::Wx::Dialog::Preferences;
	my $prefDlg = Padre::Wx::Dialog::Preferences->new;
	if ( $prefDlg->run($self) ) {
		my %mime_types; # all the mime-types of currently open files
		foreach my $editor ( $self->editors ) {
			$editor->set_preferences;
			$mime_types{ $editor->{Document}->get_mimetype } = 1;
		}

		my %new_highlighters = Padre::MimeTypes->get_current_highlighters;

		foreach my $mime_type ( keys %mime_types ) {
			my $old_highlighter = $old_highlighters{$mime_type};
			my $new_highlighter = $new_highlighters{$mime_type};
			if ( $old_highlighter ne $new_highlighter ) {
				$self->change_highlighter( $mime_type, $new_highlighter );
			}
		}

		$self->refresh_functions( $self->current );
	}
	$self->ide->save_config;

	return;
}

=pod

=head3 on_toggle_line_numbers

    $main->on_toggle_line_numbers;

Toggle visibility of line numbers on the left of the document. No
return value.

=cut

sub on_toggle_line_numbers {
	my ( $self, $event ) = @_;

	my $config = $self->config;
	$config->set( editor_linenumbers => $event->IsChecked ? 1 : 0 );

	foreach my $editor ( $self->editors ) {
		$editor->show_line_numbers( $config->editor_linenumbers );
	}

	$config->write;

	return;
}

=pod

=head3 on_toggle_code_folding

    $main->on_toggle_code_folding;

De/activate code folding. No return value.

=cut

sub on_toggle_code_folding {
	my ( $self, $event ) = @_;

	my $config = $self->config;
	$config->set( editor_folding => $event->IsChecked ? 1 : 0 );

	foreach my $editor ( $self->editors ) {
		$editor->show_folding( $config->editor_folding );
		$editor->fold_pod if ( $config->editor_folding && $config->editor_fold_pod );
	}

	$config->write;

	return;
}

=pod

=head3 on_toggle_currentline

    $main->on_toggle_currentline;

Toggle overlining of current line. No return value.

=cut

sub on_toggle_currentline {
	my ( $self, $event ) = @_;

	my $config = $self->config;
	$config->set( editor_currentline => $event->IsChecked ? 1 : 0 );

	foreach my $editor ( $self->editors ) {
		$editor->SetCaretLineVisible( $config->editor_currentline ? 1 : 0 );
	}

	$config->write;

	return;
}

=head3 on_toggle_right_margin

    $main->on_toggle_right_margin;

Toggle display of right margin. No return value.

=cut

sub on_toggle_right_margin {
	my ( $self, $event ) = @_;

	my $config = $self->config;
	$config->set( editor_right_margin_enable => $event->IsChecked ? 1 : 0 );

	my $enabled = $config->editor_right_margin_enable;
	my $col     = $config->editor_right_margin_column;

	foreach my $editor ( $self->editors ) {
		$editor->SetEdgeColumn($col);
		$editor->SetEdgeMode( $enabled ? Wx::wxSTC_EDGE_LINE : Wx::wxSTC_EDGE_NONE );
	}

	$config->write;

	return;
}

=pod

=head3 on_toggle_syntax_check

    $main->on_toggle_syntax_check;

Toggle visibility of syntax panel. No return value.

=cut

sub on_toggle_syntax_check {
	my $self  = shift;
	my $event = shift;
	$self->config->set(
		'main_syntaxcheck',
		$event->IsChecked ? 1 : 0,
	);
	$self->show_syntax( $self->config->main_syntaxcheck );
	$self->ide->save_config;
	return;
}

=pod

=head3 on_toggle_errorlist

    $main->on_toggle_errorlist;

Toggle visibility of error-list panel. No return value.

=cut

sub on_toggle_errorlist {
	my $self  = shift;
	my $event = shift;
	$self->config->set(
		'main_errorlist',
		$event->IsChecked ? 1 : 0,
	);
	if ( $self->config->main_errorlist ) {
		$self->errorlist->enable;
	} else {
		$self->errorlist->disable;
	}
	$self->ide->save_config;
	return;
}

=pod

=head3 on_toggle_indentation_guide

    $main->on_toggle_indentation_guide;

Toggle visibility of indentation guide. No return value.

=cut

sub on_toggle_indentation_guide {
	my $self  = shift;
	my $event = shift;

	$self->config->set(
		'editor_indentationguides',
		$self->menu->view->{indentation_guide}->IsChecked ? 1 : 0,
	);

	foreach my $editor ( $self->editors ) {
		$editor->SetIndentationGuides( $self->config->editor_indentationguides );
	}

	$self->config->write;

	return;
}

=pod

=head3 on_toggle_eol

    $main->on_toggle_eol;

Toggle visibility of end of line cariage returns. No return value.

=cut

sub on_toggle_eol {
	my $self   = shift;
	my $config = $self->config;

	$config->set(
		'editor_eol',
		$self->menu->view->{eol}->IsChecked ? 1 : 0,
	);

	foreach my $editor ( $self->editors ) {
		$editor->SetViewEOL( $config->editor_eol );
	}

	$config->write;

	return;
}

=pod

=head3 on_toggle_whitespaces

    $main->on_toggle_whitespaces;

Show/hide spaces and tabs (with dots and arrows respectively). No
return value.

=cut

sub on_toggle_whitespaces {
	my ($self) = @_;

	# check whether we need to show / hide spaces & tabs.
	my $config = $self->config;
	$config->set(
		'editor_whitespace',
		$self->menu->view->{whitespaces}->IsChecked
		? Wx::wxSTC_WS_VISIBLEALWAYS
		: Wx::wxSTC_WS_INVISIBLE
	);

	# update all open views with the new config.
	foreach my $editor ( $self->editors ) {
		$editor->SetViewWhiteSpace( $config->editor_whitespace );
	}

	# Save configuration
	$config->write;
}

=pod

=head3 on_word_wrap

    $main->on_word_wrap;

Toggle word wrapping for current document. No return value.

=cut

sub on_word_wrap {
	my $self = shift;
	my $on = @_ ? $_[0] ? 1 : 0 : 1;
	unless ( $on == $self->menu->view->{word_wrap}->IsChecked ) {
		$self->menu->view->{word_wrap}->Check($on);
	}

	my $doc = $self->current->document or return;

	if ($on) {
		$doc->editor->SetWrapMode(Wx::wxSTC_WRAP_WORD);
	} else {
		$doc->editor->SetWrapMode(Wx::wxSTC_WRAP_NONE);
	}
}

=pod

=head3 on_toggle_toolbar

    $main->on_toggle_toolbar;

Toggle toolbar visibility. No return value.

=cut

sub on_toggle_toolbar {
	my $self   = shift;
	my $config = $self->config;

	# Update the configuration
	$config->set(
		'main_toolbar',
		$self->menu->view->{toolbar}->IsChecked ? 1 : 0,
	);

	if ( $config->main_toolbar ) {
		$self->rebuild_toolbar;
	} else {

		# Update the tool bar
		my $toolbar = $self->GetToolBar;
		if ($toolbar) {
			$toolbar->Destroy;
			$self->SetToolBar(undef);
		} else {
			Carp::carp "error finding toolbar";
		}
	}

	# Save configuration
	$config->write;

	return;
}

=pod

=head3 on_toggle_statusbar

    $main->on_toggle_statusbar;

Toggle statusbar visibility. No return value.

=cut

sub on_toggle_statusbar {
	my $self = shift;

	# Status bar always shown on Windows
	return if Padre::Constant::WXWIN32;

	# Update the configuration
	$self->config->set(
		'main_statusbar',
		$self->menu->view->{statusbar}->IsChecked ? 1 : 0,
	);

	# Update the status bar
	if ( $self->config->main_statusbar ) {
		$self->GetStatusBar->Show;
	} else {
		$self->GetStatusBar->Hide;
	}

	# Save configuration
	$self->config->write;

	return;
}

=pod

=head3 on_toggle_lockinterface

    $main->on_toggle_lockinterface;

Toggle possibility for user to change Padre's external aspect. No
return value.

=cut

sub on_toggle_lockinterface {
	my $self   = shift;
	my $config = $self->config;

	# Update and save configuration
	$config->apply(
		'main_lockinterface',
		$self->menu->view->{lockinterface}->IsChecked ? 1 : 0,
	);
	$config->write;

	return;
}

=pod

=head3 on_insert_from_file

    $main->on_insert_from_file;

Prompt user for a file to be inserted at current position in current
document. No return value.

=cut

sub on_insert_from_file {
	my $self = shift;
	my $editor = $self->current->editor or return;

	# popup the window
	my $last_filename = $self->current->filename;
	if ($last_filename) {
		$self->{cwd} = File::Basename::dirname($last_filename);
	}
	my $dialog = Wx::FileDialog->new(
		$self,
		Wx::gettext('Open file'),
		$self->cwd,
		'',
		'*.*',
		Wx::wxFD_OPEN,
	);
	unless (Padre::Constant::WIN32) {
		$dialog->SetWildcard("*");
	}
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $filename = $dialog->GetFilename;
	$self->{cwd} = $dialog->GetDirectory;

	my $file = File::Spec->catfile( $self->cwd, $filename );
	$editor->insert_from_file($file);

	return;
}

=pod

=head3 convert_to

    $main->convert_to( $eol_style );

Convert document to C<$eol_style> line endings (can be one of C<WIN>,
C<UNIX>, or C<MAC>). No return value.

=cut

sub convert_to {
	my $self    = shift;
	my $newline = shift;
	my $current = $self->current;
	my $editor  = $current->editor;
	SCOPE: {
		no warnings 'once'; # TODO eliminate?
		$editor->ConvertEOLs( $Padre::Wx::Editor::mode{$newline} );
	}

	# TODO: include the changing of file type in the undo/redo actions
	# or better yet somehow fetch it from the document when it is needed.
	my $document = $current->document or return;
	$document->set_newline_type($newline);

	$self->refresh;
}

=pod

=head3 find_editor_of_file

    my $editor = $main->find_editor_of_file( $file );

Return the editor (a C<Padre::Wx::Editor> object) containing the wanted
C<$file>, or undef if file is not opened currently.

=cut

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

=pod

=head3 find_id_of_editor

    my $id = $main->find_id_of_editor( $editor );

Given C<$editor>, return the tab id holding it, or undef if it was
not found.

Note: can this really work? What happens when we split a window?

=cut

sub find_id_of_editor {
	my $self     = shift;
	my $editor   = shift;
	my $notebook = $self->notebook;
	foreach my $id ( $self->pageids ) {
		if ( $editor eq $notebook->GetPage($id) ) {
			return $id;
		}
	}
	return;
}

=pod

=head3 run_in_padre

    $main->run_in_padre;

Eval current document within Padre. It means it can access all of
Padre's internals, and wreck havoc. Display an error message if the eval
went wrong, dump the result in the output panel otherwise.

No return value.

=cut

sub run_in_padre {
	my $self = shift;
	my $doc  = $self->current->document or return;
	my $code = $doc->text_get;
	my @rv   = eval $code;                        ## no critic
	if ($@) {
		Wx::MessageBox(
			sprintf( Wx::gettext("Error: %s"), $@ ),
			Wx::gettext("Internal error"),
			Wx::wxOK,
			$self,
		);
		return;
	}

	# Dump the results to the output window
	require Devel::Dumpvar;
	my $dumper = Devel::Dumpvar->new( to => 'return' );
	my $string = $dumper->dump(@rv);
	$self->show_output(1);
	$self->output->clear;
	$self->output->AppendText($string);

	return;
}

=pod

=head2 STC related methods

Those methods are needed to have a smooth STC experience.

=head3 on_stc_style_needed

    $main->on_stc_style_needed( $event );

Handler of EVT_STC_STYLENEEDED C<$event>. Used to work around some edge
cases in scintilla. No return value.

=cut

sub on_stc_style_needed {
	my $self     = shift;
	my $event    = shift;
	my $current  = $self->current;
	my $document = $current->document or return;
	if ( $document->can('colorize') ) {

		# Workaround something that seems like a Scintilla bug
		# when the cursor is close to the end of the document
		# and there is code at the end of the document (and not comment)
		# the STC_STYLE_NEEDED event is being constantly called
		my $text = $document->text_get;
		if ( defined $document->{_text} and $document->{_text} eq $text ) {
			return;
		}
		$document->{_text} = $text;
		$document->colorize(
			$current->editor->GetEndStyled,
			$event->GetPosition
		);
	}
}

=pod

=head3 on_stc_update_ui

    $main->on_stc_update_ui;

Handler called on every movement of the cursor. No return value.

=cut

sub on_stc_update_ui {
	my $self = shift;

	# Avoid recursion
	return if $self->{_in_stc_update_ui};
	local $self->{_in_stc_update_ui} = 1;

	# Check for brace, on current position, higlight the matching brace
	my $current = $self->current;
	my $editor  = $current->editor;
	return if not defined $editor;
	$editor->highlight_braces;
	$editor->show_calltip;

	# Avoid refreshing the subs as that takes a lot of time
	# TODO maybe we should refresh it on every 20s hit or so
	# $self->refresh_menu;
	$self->refresh_toolbar($current);
	$self->refresh_status($current);

	# $self->refresh_functions;
	# $self->refresh_syntaxcheck;

	return;
}

=pod

=head3 on_stc_change

    $main->on_stc_change;

Handler of the EVT_STC_CHANGE event. Doesn't do anythin. No
return value.

=cut

sub on_stc_change {
	return;
}

=pod

=head3 on_stc_char_needed

    $main->on_stc_char_added;

This handler is called when a character is added. No return value. See
L<http://www.yellowbrain.com/stc/events.html#EVT_STC_CHARADDED>

TODO: maybe we need to check this more carefully.

=cut

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

=pod

=head3 on_stc_dwell_start

    $main->on_stc_dwell_start( $event );

Handler of the DWELLSTART C<$event>. This event is sent when the mouse
has not moved in a given amount of time. Doesn't do anything by now. No
return value.

=cut

sub on_stc_dwell_start {
	my ( $self, $event ) = @_;

	my $editor = $self->current->editor;

	# print "dwell: ", $event->GetPosition, "\n";
	# $editor->show_tooltip;
	# print Wx::GetMousePosition, "\n";
	# print Wx::GetMousePositionXY, "\n";

	return;
}

=pod

=head3 on_aui_pane_close

    $main->on_aui_pane_close( $event );

Handler called upon EVT_AUI_PANE_CLOSE C<$event>. Doesn't do anything by now.

=cut

sub on_aui_pane_close {
	$_[0]->GetPane;
}

=pod

=head3 on_doc_stats

    $main->on_doc_stats;

Compute various stats about current document, and display them in a
message. No return value.

=cut

sub on_doc_stats {
	my ($self) = @_;

	my $doc = $self->current->document;
	if ( not $doc ) {
		$self->message( 'No file is open', 'Stats' );
		return;
	}

	my ($lines,    $chars_with_space, $chars_without_space, $words, $is_readonly,
		$filename, $newline_type,     $encoding
	) = $doc->stats;

	my @messages = (
		sprintf( Wx::gettext("Words: %s"),                $words ),
		sprintf( Wx::gettext("Lines: %d"),                $lines ),
		sprintf( Wx::gettext("Chars without spaces: %s"), $chars_without_space ),
		sprintf( Wx::gettext("Chars with spaces: %d"),    $chars_with_space ),
		sprintf( Wx::gettext("Newline type: %s"),         $newline_type ),
		sprintf( Wx::gettext("Encoding: %s"),             $encoding ),
		sprintf( Wx::gettext("Document type: %s"), ( defined ref($doc) ? ref($doc) : Wx::gettext("none") ) ),
		defined $filename
		? sprintf( Wx::gettext("Filename: %s"), $filename )
		: Wx::gettext("No filename"),
	);
	my $message = join $/, @messages;

	if ($is_readonly) {
		$message .= "File is read-only.\n";
	}

	$self->message( $message, 'Stats' );
	return;
}

=pod

=head3 on_tab_and_space

    $main->on_tab_and_space( $style );

Convert current document from spaces to tabs (or vice-versa) depending
on C<$style> (can be either of C<Space_to_Tab> or C<Tab_to_Space>).
Prompts the user for how many spaces are to be used to replace tabs
(whatever the replacement direction). No return value.

=cut

sub on_tab_and_space {
	my $self     = shift;
	my $type     = shift;
	my $current  = $self->current;
	my $document = $current->document or return;
	my $title =
		$type eq 'Space_to_Tab'
		? Wx::gettext('Space to Tab')
		: Wx::gettext('Tab to Space');

	require Padre::Wx::History::TextEntryDialog;
	my $dialog = Padre::Wx::History::TextEntryDialog->new(
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

	my $src = $current->text;
	my $code = ($src) ? $src : $document->text_get;

	return unless ( defined $code and length($code) );

	my $to_space = ' ' x $space_num;
	if ( $type eq 'Space_to_Tab' ) {
		$code =~ s/^(\s+)/my $s = $1; $s =~ s{$to_space}{\t}g; $s/mge;
	} else {
		$code =~ s/^(\s+)/my $s = $1; $s =~ s{\t}{$to_space}g; $s/mge;
	}

	if ($src) {
		my $editor = $current->editor;
		$editor->ReplaceSelection($code);
	} else {
		$document->text_set($code);
	}
}

=pod

=head3 on_delete_ending_space

    $main->on_delete_ending_space;

Trim all ending spaces in current selection, or document if no text is
selected. No return value.

=cut

sub on_delete_ending_space {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document or return;
	my $src      = $current->text;
	my $code     = ( defined($src) && length($src) > 0 ) ? $src : $document->text_get;

	# Remove ending space
	$code =~ s/([^\n\S]+)$//mg;

	if ($src) {
		my $editor = $current->editor;
		$editor->ReplaceSelection($code);
	} else {
		$document->text_set($code);
	}
}

=pod

=head3 on_delete_leading_space

    $main->on_delete_leading_space;

Trim all leading spaces in current selection. No return value.

=cut

sub on_delete_leading_space {
	my $self    = shift;
	my $current = $self->current;
	my $src     = $current->text;
	unless ($src) {
		$self->message('No selection');
		return;
	}

	require Padre::Wx::History::TextEntryDialog;
	my $dialog = Padre::Wx::History::TextEntryDialog->new(
		$self,
		'How many leading spaces to delete(1 tab == 4 spaces):',
		'Delete Leading Space',
		'fay_delete_leading_space',
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $space_num = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $space_num and $space_num =~ /^\d+$/ ) {
		return;
	}

	my $code           = $src;
	my $spaces         = ' ' x $space_num;
	my $tab_num        = int( $space_num / 4 );
	my $space_num_left = $space_num - 4 * $tab_num;
	my $tabs           = "\t" x $tab_num;
	$tabs .= '' x $space_num_left if ($space_num_left);
	$code =~ s/^($spaces|$tabs)//mg;

	my $editor = $current->editor;
	$editor->ReplaceSelection($code);
}

=pod

=head3 timer_check_overwrite

    $main->timer_check_overwrite;

Called every n seconds to check if file has been overwritten outside of
Padre. If that's the case, prompts the user whether s/he wants to reload
the document. No return value.

=cut

sub timer_check_overwrite {
	my $self = shift;
	my $doc = $self->current->document or return;

	return unless $doc->has_changed_on_disk;
	return if $doc->{_already_popup_file_changed};

	$doc->{_already_popup_file_changed} = 1;
	my $ret = Wx::MessageBox(
		Wx::gettext("File changed on disk since last saved. Do you want to reload it?"),
		$doc->filename || Wx::gettext("File not in sync"),
		Wx::wxYES_NO | Wx::wxCENTRE,
		$self,
	);

	if ( $ret == Wx::wxYES ) {
		unless ( $doc->reload ) {
			$self->error( sprintf( Wx::gettext("Could not reload file: %s"), $doc->errstr ) );
		} else {
			$doc->editor->configure_editor($doc);
		}
	} else {
		$doc->{_timestamp} = $doc->time_on_file;
	}
	$doc->{_already_popup_file_changed} = 0;

	return;
}

=pod

=head3 on_last_visited_pane

    $main->on_last_visited_pane;

Put focus on tab visited before the current one. No return value.

=cut

sub on_last_visited_pane {
	my ( $self, $event ) = @_;
	my $history = $self->{page_history};
	if ( @$history >= 2 ) {
		@$history[ -1, -2 ] = @$history[ -2, -1 ];
		foreach my $i ( $self->pageids ) {
			my $editor = $_[0]->notebook->GetPage($i);
			if ( Scalar::Util::refaddr($editor) eq $history->[-1] ) {
				$self->notebook->SetSelection($i);
				last;
			}
		}

		# Partial refresh
		$self->refresh_status( $self->current );
		$self->refresh_toolbar( $self->current );
	}
}

=pod

=head3 on_new_from_template

    $main->on_new_from_template( $extension );

Create a new document according to template for C<$extension> type of
file. No return value.

=cut

sub on_new_from_template {
	my ( $self, $extension ) = @_;

	$self->on_new;

	my $editor = $self->current->editor or return;
	my $file = File::Spec->catfile(
		Padre::Util::sharedir('templates'),
		"template.$extension"
	);
	
	if ( $editor->insert_from_file($file) ) {
        my $document = $editor->{Document};
        $document->set_mimetype( Padre::MimeTypes->mime_type_by_extension($extension) );
        $document->editor->padre_setup;
        $document->rebless;
    }
    else {
        $self->message( sprintf(Wx::gettext("Error loading template file '%s'"), $file ));
    }
	return;
}

=pod

=head2 Auxiliary Methods

Various methods that did not fit exactly in above categories...

=head3 install_cpan

    $main->install_cpan( $module );

Install C<$module> from CPAN.

Note: this method may not belong here...

=cut

sub install_cpan {
	my $main   = shift;
	my $module = shift;

	# Run with the same Perl that launched Padre
	local $ENV{AUTOMATED_TESTING} = 1;
	Padre::CPAN->new->install($module);

	return;
}

=pod

=head3 setup_bindings

    $main->setup_bindings;

Setup the various bindings needed to handle output pane correctly.

Note: I'm not sure those are really needed...

=cut

sub setup_bindings {
	my $main = shift;
	$main->output->setup_bindings;

	# Prepare the output window
	$main->show_output(1);
	$main->output->clear;
	$main->menu->run->disable;

	return;
}

sub change_highlighter {
	my $self      = shift;
	my $mime_type = shift;
	my $module    = shift;

	# Refresh the menu (and MIME_LEXER hook)
	# probably no need for this
	# $self->refresh;

	# Update the colourise for each editor of the relevant mime-type
	# Trying to delay the actual color updating for the
	# pages that are not in focus till they get in focus
	my $focused = $self->current->editor;
	foreach my $editor ( $self->editors ) {
		my $document = $editor->{Document};
		next if $document->get_mimetype ne $mime_type;
		$document->set_highlighter($module);
		Padre::Util::debug( "Set highlighter to to $module for $document in file " . ( $document->filename || '' ) );
		my $lexer = $document->lexer;
		$editor->SetLexer($lexer);

		# TODO maybe the document should have a method that tells us if it was setup
		# to be colored by ppi or not instead of fetching the lexer again.
		Padre::Util::debug("Editor $editor focused $focused lexer: $lexer");
		if ( $editor eq $focused ) {
			$editor->needs_manual_colorize(0);
			if ( $lexer == Wx::wxSTC_LEX_CONTAINER ) {
				$document->colorize;
			} else {
				$document->remove_color;
				$editor->Colourise( 0, $editor->GetLength );
			}
		} else {
			$editor->needs_manual_colorize(1);
		}
	}

	return;
}

=pod

=head3 key_up

    $main->key_up( $event );

Callback for when a key up C<$event> happens in Padre. This handles the various
ctrl+key combinations used within Padre.

=cut

sub key_up {
	my $self  = shift;
	my $event = shift;
	my $mod   = $event->GetModifiers || 0;
	my $code  = $event->GetKeyCode;

	# Remove the bit ( Wx::wxMOD_META) set by Num Lock being pressed on Linux
	# () needed after the constants as they are functions in Perl and
	# without constants perl will call only the first one.
	$mod = $mod & ( Wx::wxMOD_ALT() + Wx::wxMOD_CMD() + Wx::wxMOD_SHIFT() );
	if ( $mod == Wx::wxMOD_CMD ) { # Ctrl
		                           # Ctrl-TAB  #TODO it is already in the menu
		if ( $code == Wx::WXK_TAB ) {
			$self->on_next_pane;
		}
	} elsif ( $mod == Wx::wxMOD_CMD() + Wx::wxMOD_SHIFT() ) { # Ctrl-Shift
		                                                      # Ctrl-Shift-TAB #TODO it is already in the menu
		$self->on_prev_pane if $code == Wx::WXK_TAB;
	} elsif ( $mod == Wx::wxMOD_ALT() ) {

		#		my $current_focus = Wx::Window::FindFocus();
		#		Padre::Util::debug("Current focus: $current_focus");
		#		# TODO this should be fine tuned later
		#		if ($code == Wx::WXK_UP) {
		#			# TODO get the list of panels at the bottom from some other place
		#			if (my $editor = $self->current->editor) {
		#				if ($current_focus->isa('Padre::Wx::Output') or
		#					$current_focus->isa('Padre::Wx::ErrorList') or
		#					$current_focus->isa('Padre::Wx::Syntax')
		#				) {
		#					$editor->SetFocus;
		#				}
		#			}
		#		} elsif ($code == Wx::WXK_DOWN) {
		#			#Padre::Util::debug("Selection: " . $self->bottom->GetSelection);
		#			#$self->bottom->GetSelection;
		#		}
	}
	$event->Skip;
	return;
}

# TODO enable/disable menu options
sub show_as_numbers {
	my ( $self, $event, $form ) = @_;

	my $current = $self->current;
	return if not $current->editor;
	my $text = $current->text;
	if ($text) {
		$self->show_output(1);
		my $output = $self->output;
		$output->Remove( 0, $output->GetLastPosition );

		# TODO deal with wide characters ?
		# TODO split lines, show location ?
		foreach my $i ( 0 .. length($text) ) {
			my $decimal = ord( substr( $text, $i, 1 ) );
			$output->AppendText( ( $form eq 'decimal' ? $decimal : uc( sprintf( '%0.2x', $decimal ) ) ) . ' ' );
		}
	} else {
		$self->message( Wx::gettext('Need to select text in order to translate to hex') );
	}

	$event->Skip;
	return;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
