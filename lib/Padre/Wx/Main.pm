package Padre::Wx::Main;

use utf8;

=encoding UTF-8

=pod

=head1 NAME

Padre::Wx::Main - The main window for the Padre IDE

=head1 DESCRIPTION

C<Padre::Wx::Main> implements Padre's main window. It is the window
containing the menus, the notebook with all opened tabs, the various
sub-windows (outline, subs, output, errors, etc).

It inherits from C<Wx::Frame>, so check Wx documentation to see all
the available methods that can be applied to it besides the added ones
(see below).

=cut

use 5.008005;
use strict;
use warnings;
use Cwd                       ();
use Carp                      ();
use Config                    ();
use File::Spec                ();
use File::Basename            ();
use File::Temp                ();
use Scalar::Util              ();
use Params::Util              ();
use Wx::Scintilla::Constant   ();
use Padre::Constant           ();
use Padre::Util               ();
use Padre::Locale             ();
use Padre::Current            ();
use Padre::DB                 ();
use Padre::Feature            ();
use Padre::Locker             ();
use Padre::Wx                 ();
use Padre::Wx::Action         ();
use Padre::Wx::ActionLibrary  ();
use Padre::Wx::Icon           ();
use Padre::Wx::Theme          ();
use Padre::Wx::Display        ();
use Padre::Wx::Menubar        ();
use Padre::Wx::Notebook       ();
use Padre::Wx::StatusBar      ();
use Padre::Wx::AuiManager     ();
use Padre::Wx::FileDropTarget ();
use Padre::Wx::Role::Conduit  ();
use Padre::Wx::Role::Dialog   ();
use Padre::Locale::T;
use Padre::Logger;

our $VERSION    = '0.94';
our $COMPATIBLE = '0.91';
our @ISA        = qw{
	Padre::Wx::Role::Conduit
	Padre::Wx::Role::Dialog
	Wx::Frame
};

use constant SECONDS => 1000;

# Wx timer ids
use constant {
	TIMER_FILECHECK => Wx::NewId(),
	TIMER_POSTINIT  => Wx::NewId(),
	TIMER_NTH       => Wx::NewId(),
};

# Convenience until we get a config param or something
use constant BACKUP_INTERVAL => 30;

# The names of our tool panels
use constant PANELS => qw{ left right bottom };

=pod

=head1 PUBLIC API

=head2 Constructor

There's only one constructor for this class.

=head3 C<new>

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
	my $ide   = shift;
	unless ( Params::Util::_INSTANCE( $ide, 'Padre' ) ) {
		Carp::croak("Did not provide an ide object to Padre::Wx::Main->new");
	}

	# Initialise the style and position
	my $config   = $ide->config;
	my $size     = [ $config->main_width, $config->main_height ];
	my $position = [ $config->main_left, $config->main_top ];
	my $style    = Wx::DEFAULT_FRAME_STYLE | Wx::CLIP_CHILDREN;

	# If we closed while maximized on the previous run,
	# the previous size is completely suspect.
	# This doesn't work on Windows,
	# so we use a different mechanism for it.
	if ( not Padre::Constant::WIN32 and $config->main_maximized ) {
		$style |= Wx::MAXIMIZE;
	}

	# Generate a smarter default size than Wx does
	if ( grep { defined $_ and $_ eq '-1' } ( @$size, @$position ) ) {
		my $rect = Padre::Wx::Display::primary_default();
		$size     = $rect->GetSize;
		$position = $rect->GetPosition;
	}

	# Create the underlying Wx frame
	my $self = $class->SUPER::new(
		undef,
		-1,
		'Padre',
		$position,
		$size,
		$style,
	);

	# On Windows you need to create the window and maximise it
	# as two separate steps. Doing this makes the window layout look
	# wrong, but at least it has the correct proportions. To fix the
	# buggy layout we will unmaximize and remaximize it again later
	# just before we ->Show the window.
	if ( Padre::Constant::WIN32 and $config->main_maximized ) {
		$self->Maximize(1);
	}

	# Start with a simple placeholder title
	$self->SetTitle('Padre');

	# Save a reference back to the parent IDE
	$self->{ide} = $ide;

	# Save a reference to the configuration object.
	# This prevents tons of ide->config
	$self->{config} = $config;

	# Remember where the editor started from this could be handy later.
	$self->{cwd} = Cwd::cwd();

	# There is a directory locking problem on Win32.
	# If we open Padre from a directory and leave the Cwd cursor
	# in that directory, then it can NEVER be deleted.
	# Having recorded the "current working directory" move
	# the OS directory cursor away from this starting directory,
	# so that Padre won't hold an implicit OS lock on it.
	# NOTE: If changing the directory fails, ignore errors for now,
	#       since that means we have WAY bigger problems.
	if (Padre::Constant::WIN32) {
		require File::HomeDir;
		chdir( File::HomeDir->my_home );
	}

	# Create the lock manager before any gui operations,
	# so that we can do locking operations during startup.
	$self->{locker} = Padre::Locker->new($self);

	# Bootstrap locale support before we start fiddling with the GUI.
	my $startup_locale = $ide->opts->{startup_locale};
	$self->{locale} = ( $startup_locale ? Padre::Locale::object($startup_locale) : Padre::Locale::object() );

	# Bootstrap style information in case the GUI will need it
	$self->{theme} = Padre::Wx::Theme->find( $config->editor_style );

	# A large complex application looks, frankly, utterly stupid
	# if it gets very small, or even mildly small.
	$self->SetMinSize( Wx::Size->new( 500, 400 ) );

	# Bootstrap drag and drop support
	Padre::Wx::FileDropTarget->set($self);

	# Bootstrap the action system
	Padre::Wx::ActionLibrary->init($self);

	# Temporary store for the notebook tab history
	# TO DO: Storing this here (might) violate encapsulation.
	#       It should probably be in the notebook object.
	$self->{page_history} = [];

	# Set the window manager
	$self->{aui} = Padre::Wx::AuiManager->new($self);

	# Add some additional attribute slots
	$self->{marker} = {};

	# Backup time tracking
	$self->{backup} = 0;

	# Create the menu bar
	$self->{menu} = Padre::Wx::Menubar->new($self);
	$self->SetMenuBar( $self->{menu}->wx );

	# Create the tool bar
	if ( $config->main_toolbar ) {
		require Padre::Wx::ToolBar;
		$self->SetToolBar( Padre::Wx::ToolBar->new($self) );
		$self->GetToolBar->Realize;
	}

	# Create the status bar
	my $statusbar = Padre::Wx::StatusBar->new($self);
	$self->SetStatusBar($statusbar);

	# Create the notebooks (document and tools) that
	# serve as the main AUI manager GUI elements.
	$self->{notebook} = Padre::Wx::Notebook->new($self);

	# Use Padre's icon
	if (Padre::Constant::WIN32) {

		# Windows needs its ICO'n file for Padre to look cooler in
		# the task bar, task switch bar and task manager
		$self->SetIcons(Padre::Wx::Icon::PADRE_ICON_FILE);
	} else {
		$self->SetIcon(Padre::Wx::Icon::PADRE);
	}

	# Activate Padre after a period not showing Padre
	Wx::Event::EVT_ACTIVATE(
		$self,
		sub {
			if ( $_[1]->GetActive ) {
				return shift->on_activate(@_);
			} else {
				return shift->on_deactivate(@_);
			}
		},
	);

	# Deal with someone closing the window
	Wx::Event::EVT_CLOSE(
		$self,
		sub {
			shift->on_close_window(@_);
		},
	);

	# Save maximize state after it changes
	Wx::Event::EVT_MAXIMIZE(
		$self,
		sub {
			shift->window_save;
			shift->Skip(1);
		},
	);

	# Save window position whenever the window is moved
	Wx::Event::EVT_MOVE(
		$self,
		sub {
			shift->window_save;
			shift->Skip(1);
		},
	);

	# Set up the pane close event
	Wx::Event::EVT_AUI_PANE_CLOSE(
		$self,
		sub {
			shift->on_aui_pane_close(@_);
		},
	);

	# Special Key Handling
	Wx::Event::EVT_KEY_UP(
		$self,
		sub {
			shift->key_up(@_);
		},
	);

	# Scintilla Event Hooks
	# We delay per-stc-update processing until idle.
	# This is primarily due to a defect http://trac.wxwidgets.org/ticket/4272:
	# No status bar updates during STC_PAINTED, which we appear to hit on UPDATEUI.
	Wx::Event::EVT_STC_UPDATEUI(
		$self, -1,
		sub {
			shift->{_do_update_ui} = 1;
		}
	);

	Wx::Event::EVT_IDLE(
		$self,
		sub {
			my $self = shift;
			if ( $self->{_do_update_ui} ) {
				$self->{_do_update_ui} = undef;
				$self->on_stc_update_ui;
			}
		}
	);

	Wx::Event::EVT_STC_CHANGE( $self, -1, \&on_stc_change );
	Wx::Event::EVT_STC_STYLENEEDED( $self, -1, \&on_stc_style_needed );
	Wx::Event::EVT_STC_CHARADDED( $self, -1, \&on_stc_char_added );

	# Show the tools that the configuration dictates.
	# Use the fast and crude internal versions here only,
	# so we don't accidentally trigger any configuration writes.
	$self->show_view( todo      => $config->main_todo      );
	$self->show_view( functions => $config->main_functions );
	$self->show_view( outline   => $config->main_outline   );
	$self->show_view( directory => $config->main_directory );
	$self->show_view( syntax    => $config->main_syntax    );
	$self->show_view( output    => $config->main_output    );
	if (Padre::Feature::COMMAND)                             {
		$self->show_view( command => $config->main_command );
	}
	if (Padre::Feature::VCS) {
		$self->show_view( vcs => $config->main_vcs );
	}
	if (Padre::Feature::CPAN) {
		$self->show_view( cpan => $config->main_cpan );
	}
	$self->show_view( debugger    => $config->main_debugger );
	$self->show_view( breakpoints => $config->main_breakpoints );
	$self->show_view( debugoutput => $config->main_debugoutput );

	# Lock the panels if needed
	$self->aui->lock_panels( $config->main_lockinterface );

	# This require is only here so it can follow this constructor
	# when it moves to being created on demand.
	if (Padre::Feature::DEBUGGER) {

		# Reset the value to the default setting
		my $name  = "main_toolbar_items";
		my $value = $config->main_toolbar_items;
		$config->apply( $name, $value );
	}

	# We need an event immediately after the window opened
	# (we had an issue that if the default of main_statusbar was false it did
	# not show the status bar which is ok, but then when we selected the menu
	# to show it, it showed at the top) so now we always turn the status bar on
	# at the beginning and hide it in the timer, if it was not needed
	# TO DO: there might be better ways to fix that issue...
	#$statusbar->Show;
	my $timer = Wx::Timer->new( $self, TIMER_POSTINIT );
	Wx::Event::EVT_TIMER(
		$self,
		TIMER_POSTINIT,
		sub {
			$_[0]->timer_start;
		},
	);
	$timer->Start( 1, 1 );

	return $self;
}

# HACK: When the $Padre::INVISIBLE variable is set (during testing) never
# show the main window. This exists because people tend to get annoyed when
# you flicker a bunch of windows on and off the screen during testing.
sub Show {
	return shift->SUPER::Show( $Padre::Test::VERSION ? 0 : @_ );
}

# This is effectively the second half of the constructor, which is delayed
# until after the window has been shown and the main loop has been started.
# All loading and initialisation which is expensive or needs a running
# application (with gui tools and threads and so on) go here.
sub timer_start {
	my $self    = shift;
	my $config  = $self->config;
	my $manager = $self->ide->plugin_manager;

	# Do an initial Show/paint of the complete-looking main window
	# without any files loaded. We'll then immediately start an
	# update lock so that loading of the files is done in a single
	# render pass.
	# This gives us an optimum compromise between being PERCEIVED
	# to start-up quickly, and ACTUALLY starting up quickly.
	if ( Padre::Constant::WIN32 and $config->main_maximized ) {

		# This is a hacky workaround for buggy maximise-at-startup
		# layout generation on windows.
		my $lock = $self->lock('UPDATE');
		$self->Maximize(0);
		$self->Show(1);
		$self->Maximize(1);
	} else {
		$self->Show(1);
	}

	# If the position mandated by the configuration is now
	# off the screen (typically because we've changed the screen
	# size, reposition to the defaults).
	# This must happen AFTER the initial ->Show(1) because otherwise
	# ->IsShownOnScreen returns a false-negative result.
	unless ( Padre::Wx::Display->perfect($self) ) {
		my $rect = Padre::Wx::Display::primary_default();
		$self->SetSizeRect($rect);
	}

	# Lock everything during the initial opening of files.
	# Run a whole bunch of refresh methods when this is done,
	# as we will be in our final startup editor state and can be
	# sure it won't change on us in the future.
	# Anything else that needs to have it's refresh method called
	# as part of initialisation should be added to the list here.
	SCOPE: {
		my $lock = $self->lock(
			qw{
				UPDATE DB
				refresh
				refresh_recent
				refresh_windowlist
				}
		);

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
	}

	# Start the single instance server
	if ( $config->main_singleinstance ) {
		$self->single_instance_start;
	}

	# Check for new plug-ins and alert the user to them
	$manager->alert_new;

	# Start the change detection timer
	my $timer1 = Wx::Timer->new( $self, TIMER_FILECHECK );
	Wx::Event::EVT_TIMER(
		$self,
		TIMER_FILECHECK,
		sub {
			$_[0]->timer_check_overwrite;
		},
	);
	$timer1->Start( $config->update_file_from_disk_interval * SECONDS, 0 );

	# Start the second-generation task manager
	$self->ide->task_manager->start;

	# Give a chance for post-start code to run, then do the nth-start logic
	my $timer2 = Wx::Timer->new( $self, TIMER_NTH );
	Wx::Event::EVT_TIMER(
		$self,
		TIMER_NTH,
		sub {
			$_[0]->timer_nth;
		},
	);
	$timer2->Start( 1 * SECONDS, 1 );

	return;
}

sub timer_nth {
	my $self = shift;

	# Hand off to the nth start system
	unless ($Padre::Test::VERSION) {
		require Padre::Wx::Nth;
		Padre::Wx::Nth->nth( $self, $self->config->nth_startup );
	}

	return 1;
}





#####################################################################

=pod

=head2 Accessors

The following methods access the object attributes. They are both
getters and setters, depending on whether you provide them with an
argument. Use them wisely.

Accessors to GUI elements:

=over 4

=item * C<title>

=item * C<config>

=item * C<aui>

=item * C<menu>

=item * C<notebook>

=item * C<left>

=item * C<right>

=item * C<functions>

=item * C<todo>

=item * C<outline>

=item * C<directory>

=item * C<bottom>

=item * C<output>

=item * C<syntax>

=item * C<vcs>

=back

Accessors to operating data:

=over 4

=item * C<cwd>

=back

Accessors that may not belong to this class:

=cut

use Class::XSAccessor {
	predicates => {

		# Needed for lazily-constructed GUI elements
		has_about          => 'about',
		has_left           => 'left',
		has_right          => 'right',
		has_bottom         => 'bottom',
		has_breakpoints    => 'breakpoints',
		has_debugoutput    => 'debugoutput',
		has_debugger       => 'debugger',
		has_output         => 'output',
		has_command        => 'command',
		has_syntax         => 'syntax',
		has_vcs            => 'vcs',
		has_cpan           => 'cpan',
		has_functions      => 'functions',
		has_todo           => 'todo',
		has_outline        => 'outline',
		has_directory      => 'directory',
		has_find           => 'find',
		has_findfast       => 'findfast',
		has_findinfiles    => 'findinfiles',
		has_foundinfiles   => 'foundinfiles',
		has_replace        => 'replace',
		has_replaceinfiles => 'replaceinfiles',
		has_goto           => 'goto',
	},
	getters => {

		# GUI Elements
		ide                 => 'ide',
		config              => 'config',
		title               => 'title',
		theme               => 'theme',
		aui                 => 'aui',
		menu                => 'menu',
		notebook            => 'notebook',
		infomessage         => 'infomessage',
		infomessage_timeout => 'infomessage_timeout',

		# Operating Data
		locker => 'locker',
		cwd    => 'cwd',
		search => 'search',
	},
};

=pod

=head3 C<left>

    my $panel = $main->left;

Returns the left toolbar container panel, creating it if needed.

=cut

sub left {
	my $self = shift;
	unless ( defined $self->{left} ) {
		require Padre::Wx::Left;
		$self->{left} = Padre::Wx::Left->new($self);
	}
	return $self->{left};
}

=pod

=head3 C<right>

    my $panel = $main->right;

Returns the right toolbar container panel, creating it if needed.

=cut

sub right {
	my $self = shift;
	unless ( defined $self->{right} ) {
		require Padre::Wx::Right;
		$self->{right} = Padre::Wx::Right->new($self);
	}
	return $self->{right};
}

=pod

=head3 C<bottom>

    my $panel = $main->bottom;

Returns the bottom toolbar container panel, creating it if needed.

=cut

sub bottom {
	my $self = shift;
	unless ( defined $self->{bottom} ) {
		require Padre::Wx::Bottom;
		$self->{bottom} = Padre::Wx::Bottom->new($self);
	}
	return $self->{bottom};
}

sub output {
	my $self = shift;
	unless ( defined $self->{output} ) {
		require Padre::Wx::Output;
		$self->{output} = Padre::Wx::Output->new($self);
	}
	return $self->{output};
}

BEGIN {
	no warnings 'once';
	*command = sub {
		my $self = shift;
		unless ( defined $self->{command} ) {
			require Padre::Wx::Command;
			$self->{command} = Padre::Wx::Command->new($self);
		}
		return $self->{command};
	} if Padre::Feature::COMMAND;
}

sub functions {
	my $self = shift;
	unless ( defined $self->{functions} ) {
		require Padre::Wx::FunctionList;
		$self->{functions} = Padre::Wx::FunctionList->new($self);
	}
	return $self->{functions};
}

sub todo {
	my $self = shift;
	unless ( defined $self->{todo} ) {
		require Padre::Wx::TodoList;
		$self->{todo} = Padre::Wx::TodoList->new($self);
	}
	return $self->{todo};
}

sub syntax {
	my $self = shift;
	unless ( defined $self->{syntax} ) {
		require Padre::Wx::Syntax;
		$self->{syntax} = Padre::Wx::Syntax->new($self);
	}
	return $self->{syntax};
}

sub vcs {
	my $self = shift;
	unless ( defined $self->{vcs} ) {
		require Padre::Wx::VCS;
		$self->{vcs} = Padre::Wx::VCS->new($self);
	}
	return $self->{vcs};
}

sub cpan {
	my $self = shift;
	unless ( defined $self->{cpan} ) {
		require Padre::Wx::CPAN;
		$self->{cpan} = Padre::Wx::CPAN->new($self);
	}
	return $self->{cpan};
}

sub debugger {
	my $self = shift;
	unless ( defined $self->{debugger} ) {
		require Padre::Wx::Panel::Debugger;
		$self->{debugger} = Padre::Wx::Panel::Debugger->new($self);
	}
	return $self->{debugger};
}

sub breakpoints {
	my $self = shift;
	unless ( defined $self->{breakpoints} ) {
		require Padre::Wx::Panel::Breakpoints;
		$self->{breakpoints} = Padre::Wx::Panel::Breakpoints->new($self);
	}
	return $self->{breakpoints};
}

sub debugoutput {
	my $self = shift;
	unless ( defined $self->{debugoutput} ) {
		require Padre::Wx::Panel::DebugOutput;
		$self->{debugoutput} = Padre::Wx::Panel::DebugOutput->new($self);
	}
	return $self->{debugoutput};
}

sub diff {
	my $self = shift;
	unless ( defined $self->{diff} ) {
		require Padre::Wx::Diff;
		$self->{diff} = Padre::Wx::Diff->new($self);
	}
	return $self->{diff};
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

sub replaceinfiles {
	my $self = shift;
	unless ( defined $self->{replaceinfiles} ) {
		require Padre::Wx::ReplaceInFiles;
		$self->{replaceinfiles} = Padre::Wx::ReplaceInFiles->new($self);
	}
	return $self->{replaceinfiles};
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
	my $self  = shift;
	my $topic = shift;
	unless ( defined $self->{help_search} ) {
		require Padre::Wx::Dialog::HelpSearch;
		$self->{help_search} = Padre::Wx::Dialog::HelpSearch->new($self);
	}
	$self->{help_search}->show($topic);
}

=pod

=head3 C<find>

    my $dialog = $main->find;

Returns the Find dialog, creating it if needed.

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

=head3 C<findfast>

    my $find = $main->findfast;

Returns the Fast Find panel, creating it if needed.

=cut

sub findfast {
	my $self = shift;
	unless ( defined $self->{findfast} ) {
		require Padre::Wx::Panel::FindFast;
		$self->{findfast} = Padre::Wx::Panel::FindFast->new($self);
	}
	return $self->{findfast};
}

=pod

=head2 C<findinfiles>

    my $dialog = $main->findinfiles;

Returns the Find in Files dialog, creating it if needed.

=cut

sub findinfiles {
	my $self = shift;
	unless ( defined $self->{findinfiles} ) {
		require Padre::Wx::Dialog::FindInFiles;
		$self->{findinfiles} = Padre::Wx::Dialog::FindInFiles->new($self);
	}
	return $self->{findinfiles};
}

=pod

=head2 C<foundinfiles>

    my $panel = $main->foundinfiles;

Returns the Find in Files results panel, creating it if needed.

=cut

sub foundinfiles {
	my $self = shift;
	unless ( defined $self->{foundinfiles} ) {
		require Padre::Wx::Panel::FoundInFiles;
		$self->{foundinfiles} = Padre::Wx::Panel::FoundInFiles->new($self);
	}
	return $self->{foundinfiles};
}

=pod

=head3 C<replace>

    my $dialog = $main->replace;

Return current Find and Replace dialog. Create a new one if needed.

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

=head3 C<goto>

    my $dialog = $main->goto;

Return the Goto dialog. Create a new one if needed.

=cut

sub goto {
	my $self = shift;
	unless ( defined $self->{goto} ) {
		require Padre::Wx::Dialog::Goto;
		$self->{goto} = Padre::Wx::Dialog::Goto->new($self);
	}
	return $self->{goto};
}

=pod

=head2 Public Methods

=head3 C<load_files>

    $main->load_files;

Load any default files: session from command-line, explicit list on command-
line, or last session if user has this setup, a new file, or nothing.

=cut

sub load_files {
	my $self    = shift;
	my $ide     = $self->ide;
	my $config  = $self->config;
	my $startup = $config->startup_files;

	# explicit session on command line takes precedence
	if ( defined $ide->opts->{session} ) {

		# try to find the wanted session...
		my ($session) = Padre::DB::Session->select(
			'where name = ?', $ide->opts->{session},
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

	# Otherwise, an explicit list on the command line overrides configuration
	my $files = $ide->{ARGV};
	if ( Params::Util::_ARRAY($files) ) {
		$self->setup_editors(@$files);
		return;
	}

	# Config setting 'last' means start-up with all the files from the
	# previous time we used Padre open (if they still exist)
	if ( $startup eq 'last' ) {
		my $session = Padre::DB::Session->last_padre_session;
		$self->open_session($session) if defined($session);
		return;
	}

	# Config setting 'session' means: Show the session manager
	if ( $startup eq 'session' ) {
		require Padre::Wx::Dialog::SessionManager;
		Padre::Wx::Dialog::SessionManager->new($self)->show;
		return;
	}

	# Last session functionality is not in use, do we disable it for
	# performance reasons (it's expensive to maintain the session).
	# Remove the session if it exists, because we won't be saving
	# this information and we don't want an old stale session to
	# be hanging around in the database pointlessly.
	Padre::DB::Session->clear_last_session;

	# Config setting 'nothing' means start-up with nothing open
	if ( $startup eq 'nothing' ) {
		return;
	}

	# Config setting 'new' means start-up with a single new file open
	if ( $startup eq 'new' ) {
		$self->setup_editors;
		return;
	}

	# Configuration has an entry we don't know about
	# TO DO: Once we have a warning system more useful than STDERR
	# add a warning. For now though, just do nothing and ignore.
	return;
}

=pod

=head3 C<lock>

  my $lock = $main->lock('UPDATE', 'BUSY', 'refresh_toolbar');

Create and return a guard object that holds resource locks of various types.

The method takes a parameter list of the locks you wish to exist for the
current scope. Special types of locks are provided in capitals,
refresh/method locks are provided in lowercase.

The C<UPDATE> lock creates a Wx repaint lock using the built in
L<Wx::WindowUpdateLocker> class.

You should use an update lock during GUI construction/modification to
prevent screen flicker. As a side effect of not updating, the GUI changes
happen B<significantly> faster as well. Update locks should only be held for
short periods of time, as the operating system will begin to treat your\
application as "hung" if an update lock persists for more than a few
seconds. In this situation, you may begin to see GUI corruption.

The C<BUSY> lock creates a Wx "busy" lock using the built in
L<Wx::WindowDisabler> class.

You should use a busy lock during times when Padre has to do a long and/or
complex operation in the foreground, or when you wish to disable use of any
user interface elements until a background thread is finished.

Busy locks can be held for long periods of time, however your users may
start to suspect trouble if you do not provide any periodic feedback to them.

Lowercase lock names are used to delay the firing of methods that will
themselves generate GUI events you may want to delay until you are sure
you want to rebuild the GUI.

For example, opening a file will require a Padre::Wx::Main refresh call,
which will itself generate more refresh calls on the directory browser, the
function list, output window, menus, and so on.

But if you open more than one file at a time, you don't want to refresh the
menu for the first file, only to do it again on the second, third and
fourth files.

By creating refresh locks in the top level operation, you allow the lower
level operation to make requests for parts of the GUI to be refreshed, but
have the actual refresh actions delayed until the lock expires.

This should make operations with a high GUI intensity both simpler and
faster.

The name of the lowercase MUST be the name of a Padre::Wx::Main method,
which will be fired (with no parameters) when the method lock expires.

=cut

sub lock {
	shift->{locker}->lock(@_);
}

=pod

=head3 C<locked>

This method provides the ability to check if a resource is currently locked.

=cut

sub locked {
	shift->{locker}->locked(@_);
}

=pod

=head2 Single Instance Server

Padre embeds a small network server to handle single instance. Here are
the methods that allow to control this embedded server.

=head3 C<single_instance_address>

    $main->single_instance_address;

Determines the location of the single instance server for this instance of
L<Padre>.

=cut

sub single_instance_address {
	my $self   = shift;
	my $config = $self->config;

	require Wx::Socket;
	if (Padre::Constant::WIN32) {

		# Since using a Wx::IPv4address doesn't seem to work,
		# for now just return the two-value host/port list.
		# my $address = Wx::IPV4address->new;
		# $address->SetHostname('127.0.0.1');
		# $address->SetService('4444');
		# return $address;
		return (
			'127.0.0.1',
			$config->main_singleinstance_port,
		);
	} else {

		# Fix for #1138, remove the part following the return once the
		# fix has been tested propably
		return (
			'127.0.0.1',
			$config->main_singleinstance_port
		);

		# TODO: Keep this until someone on Unix has time to test it
		# my $file = File::Spec->catfile(
		# Padre::Constant::CONFIG_DIR,
		# 'single_instance.socket',
		# );
		# my $address = Wx::UNIXaddress->new;
		# $address->SetFilename($file);
		# return $address;
	}
}

=pod

=head3 C<single_instance_start>

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
		$self->single_instance_address,
		Wx::SOCKET_NOWAIT | Wx::SOCKET_REUSEADDR,
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

=head3 C<single_instance_stop>

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

=head3 C<single_instance_running>

    my $is_running = $main->single_instance_running;

Return true if the embedded server is currently running.

=cut

sub single_instance_running {
	return defined $_[0]->{single_instance};
}

=pod

=head3 C<single_instance_connect>

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
					$_[1]->single_instance_command( "$1", $_[0] );
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

=head3 C<single_instance_command>

    $main->single_instance_command( $line );

Callback called when a client has issued a command C<$line> while
connected on embedded server. Current supported commands are C<open
$file> and C<focus>.

=cut

my $single_instance_raised = 0;

sub single_instance_command {
	my $self   = shift;
	my $line   = shift;
	my $socket = shift;

	# $line should be defined
	return 1 unless defined $line && length $line;

	# ignore the line if command isn't plain ascii
	return 1 unless $line =~ s/^(\S+)\s*//s;

	if ( $1 eq 'focus' ) {

		# Try to give focus to Padre IDE. It might not work,
		# since some window manager implement some kind of focus-
		# stealing prevention.

		# First, let's deiconize Padre if needed
		$self->Iconize(0) if $self->IsIconized;

		# Now let's raise Padre
		# We have to do both or (on Win32 at least)
		# the Raise call only works the first time.
		if (Padre::Constant::WIN32) {
			if ( $single_instance_raised++ ) {

				# After the first time, this seems to work
				$self->Lower;
				$self->Raise;
			} else {

				# The first time this behaves weirdly
				$self->Raise;
			}
		} else {

			# We trust non-Windows to behave sanely
			$self->Raise;
		}

	} elsif ( $1 eq 'open' ) {
		if ( -f $line ) {

			# If a file is already loaded switch to it instead
			$self->notebook->show_file($line)
				or $self->setup_editors($line);
		}

	} elsif ( $1 eq 'open-sync' ) {

		# XXX: This should be two commands, 'open'+'wait-for-close'
		my $editor;
		if ( -f $line ) {

			# If a file is already loaded switch to it instead
			$editor = $self->notebook->show_file($line);
			$editor ||= $self->setup_editors($line);
		}

		# Notify the client when we close this window
		$self->{on_close_watchers} ||= {};
		$self->{on_close_watchers}->{$line} ||= [];
		push @{ $self->{on_close_watchers}->{$line} }, sub {

			#warn "Closing $line / " . $_[0]->filename;
			my $buf = "closed:$line\r\n"
				; # XXX Should we worry about encoding things as utf-8 or do we rely on both client and server speaking the same filesystem encoding?
			$socket->Write( $buf, length($buf) ); # XXX length is encoding-sensitive!
			return 1;                             # signal that we want to be removed
		};

	} else {

		# d'oh! embedded server can't do anything
		warn("Unsupported command '$1'");
	}

	return 1;
}

=pod

=head2 Window Geometry

Query properties about the state and shape of the main window

=head3 C<window_width>

    my $width = $main->window_width;

Return the main window width.

=cut

sub window_width {
	( $_[0]->GetSizeWH )[0];
}

=pod

=head3 C<window_height>

    my $width = $main->window_height;

Return the main window height.

=cut

sub window_height {
	( $_[0]->GetSizeWH )[1];
}

=pod

=head3 C<window_left>

    my $left = $main->window_left;

Return the main window position from the left of the screen.

=cut

sub window_left {
	( $_[0]->GetPositionXY )[0];
}

=pod

=head3 C<window_top>

    my $top = $main->window_top;

Return the main window position from the top of the screen.

=cut

sub window_top {
	( $_[0]->GetPositionXY )[1];
}

=pod

=head3 C<window_save>

    $main->window_save;

Saves the current main window geometry (left, top, width, height, maximized).

Called during Maximize, Iconize, ShowFullScreen and Padre shutdown
so we can restart the next Padre instance at the last good
non-Maximize/Iconize location.

Saves and returns true if and only the window is regular or maximized.

Skips and returns false if the window is currently hidden, iconised,
or full screen.

=cut

sub window_save {
	my $self = shift;

	# Skip situations we can't record anything
	return 0 unless $self->IsShown;
	return 0 if $self->IsIconized;
	return 0 if $self->IsFullScreen;

	# Prepare the config "transaction"
	my $lock   = $self->lock('CONFIG');
	my $config = $self->config;
	if ( $self->IsMaximized ) {

		# We are maximized, just save that fact
		$config->set( main_maximized => 1 );

	} else {

		# We are a regular window, save everything
		my ( $width, $height ) = $self->GetSizeWH;
		my ( $left,  $top )    = $self->GetPositionXY;
		$config->set( main_width     => $width );
		$config->set( main_height    => $height );
		$config->set( main_left      => $left );
		$config->set( main_top       => $top );
		$config->set( main_maximized => 0 );
	}

	return 1;
}

=pod

=head2 Refresh Methods

Those methods refresh parts of Padre main window. The term C<refresh>
and the following methods are reserved for fast, blocking, real-time
updates to the GUI, implying rapid changes.

=head3 C<refresh>

    $main->refresh;

Force refresh of all elements of Padre main window. (see below for
individual refresh methods)

=cut

sub refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	return if $self->locked('REFRESH');

	# Freeze during the refresh
	my $lock    = $self->lock('UPDATE');
	my $current = $self->current;

	# Although it would be nice to do this later, some of the
	# optimisations in the other refresh subsections depend on the
	# checked-state of the menu entries being accurate. So alas, we must
	# do this one first and delay the background jobs a little.
	$self->refresh_menu($current);

	# Refresh elements that generate background tasks first,
	# so those tasks will run while we do the other things.
	# Tasks that run more often go before those that don't,
	# which has a slightly positive effect on specialisation
	# of background workers.
	$self->refresh_directory($current);
	$self->refresh_syntax($current);
	$self->refresh_functions($current);
	$self->refresh_outline($current);
	$self->refresh_diff($current);
	if (Padre::Feature::VCS) {
		$self->refresh_vcs($current);
	}

	# Refresh the remaining elements while the background tasks
	# are running for the other elements.
	$self->refresh_title($current);
	$self->refresh_notebook($current);
	$self->refresh_toolbar($current);
	$self->refresh_status($current);

	# Now signal the refresh to all remaining listeners
	# weed out expired weak references
	@{ $self->{refresh_listeners} } = grep { ; defined } @{ $self->{refresh_listeners} };
	for ( @{ $self->{refresh_listeners} } ) {
		if ( my $refresh = $_->can('refresh') ) {
			$_->refresh($current);
		} else {
			$_->($current);
		}
	}

	my $notebook = $self->notebook;
	if ( $notebook->GetPageCount ) {
		my $id = $notebook->GetSelection;
		if ( defined $id and $id >= 0 ) {
			$notebook->GetPage($id)->SetFocus;
		}

		# $self->aui->GetPane('notebook')->PaneBorder(0);
		# } else {
		# $self->aui->GetPane('notebook')->PaneBorder(1);
	}

	return;
}

=pod

=head3 C<add_refresh_listener>

Adds an object which will have its C<< ->refresh >> method
called whenever the main refresh event is triggered. The
refresh listener is stored as a weak reference so make sure
that you keep the listener alive elsewhere.

If your object does not have a C<< ->refresh >> method, pass in
a code reference - it will be called instead.

Note that this method must return really quick. If you plan to
do work that takes longer, launch it via the L<Action::Queue> mechanism
and perform it in the background.

=cut

sub add_refresh_listener {
	my ( $self, @listeners ) = @_;
	foreach my $l (@listeners) {
		if ( !grep { $_ eq $l } @{ $self->{refresh_listeners} } ) {
			Scalar::Util::weaken($l);
			push @{ $self->{refresh_listeners} }, $l;
		}
	}
}

=pod

=head3 C<refresh_title>

Sets or updates the Window title.

=cut

sub refresh_title {
	my $self = shift;
	return if $self->locked('REFRESH');

	# Get the window title template string
	my $current  = Padre::Current::_CURRENT(@_);
	my $config   = $current->config;
	my $template = $config->main_title || 'Padre %v';

	my $title = $self->process_template($template);

	# Additional information if we are running the developer version
	require Padre::Util::SVN;
	my $revision = Padre::Util::SVN::padre_revision();
	if ( defined $revision ) {
		$title .= " SVN \@$revision (\$VERSION = $Padre::VERSION)";
	}

	unless ( $self->GetTitle eq $title ) {

		# Push the title to the window
		$self->SetTitle($title);

		# Push the title to the process list for better identification
		$0 = $title; ## no critic (RequireLocalizedPunctuationVars)
	}

	return;
}

# this sub is called frequently, on every key stroke or mouse movement
# TODO speed should be improved
sub process_template_frequent {
	my $self     = shift;
	my $template = shift;

	my $current = Padre::Current::_CURRENT(@_);

	my $document = $current->document;

	if ( $template =~ /\%m/ ) {
		if ($document) {
			my $modified = $document->editor->GetModify ? '*' : '';
			$template =~ s/\%m/$modified/;
		} else {
			$template =~ s/\%m/*/; # maybe set to '' if document is empty?
		}
	}

	if ( $template =~ /\%s/ ) {
		my $sub = '';
		if ($document) {
			my $text   = $document->text_get;
			my $editor = $document->editor;
			my $pos    = $editor->GetCurrentPos;
			my $first  = $editor->PositionFromLine(0);
			my $prefix = $editor->GetTextRange( $first, $pos );

			require Padre::Search;
			my ( $start, $end ) = Padre::Search->matches(
				text      => $prefix,
				regex     => $document->get_function_regex(qr/\w+/),
				submatch  => 1,
				from      => 0,
				to        => length($prefix),
				backwards => 1,
			);
			if ( defined $start and defined $end ) {
				my $match = substr( $prefix, $start, ( $end - $start ) );
				my ( $p, $name ) = split /\s+/, $match;
				$sub = $name;
			} else {
				$sub = '';
			}
		} else {
			$sub = '';
		}
		$template =~ s/\%s/$sub/;
	}

	return $template;
}

sub process_template {
	my $self     = shift;
	my $template = shift;

	my $current = Padre::Current::_CURRENT(@_);

	# Populate any variables used in the template on demand,
	# avoiding potentially expensive operations unless needed.
	my %variable = (
		'%' => '%',
		'v' => $Padre::VERSION,
	);
	foreach my $char ( $template =~ /\%(.)/g ) {
		next if exists $variable{$char};

		if ( $char eq 'p' ) {

			# Fill in the session name, if any
			if ( defined $self->ide->{session} ) {
				my ($session) = Padre::DB::Session->select(
					'where id = ?', $self->ide->{session},
				);
				$variable{p} = $session->name;
			} else {
				$variable{p} = '';
			}
			next;
		}

		# The other variables are all based on the filename
		my $document = $current->document;
		my $file;
		$file = $document->file if defined $document;

		unless ( defined $file ) {
			if ( $char =~ m/^[fbdF]$/ ) {
				$variable{$char} = '';
			} else {
				$variable{$char} = '%' . $char;
			}
			next;
		}

		if ( $char eq 'b' ) {
			$variable{b} = $file->basename;
		} elsif ( $char eq 'd' ) {
			$variable{d} = $file->dirname;
		} elsif ( $char eq 'f' ) {
			$variable{f} = $file->{filename};
		} elsif ( $char eq 'F' ) {

			# Filename relative to the project root
			$variable{F} = $file->{filename};
			my $project_dir = $document->project_dir;
			if ( defined $project_dir ) {
				$project_dir = quotemeta $project_dir;
				$variable{F} =~ s/^$project_dir//;
			}
		} else {
			$variable{$char} = '%' . $char;
		}
	}

	# Process the template into the final string
	$template =~ s/\%(.)/$variable{$1}/g;

	return $template;
}


=pod

=head3 C<refresh_syntax>

    $main->refresh_syntax;

Do a refresh of document syntax checking. This is a "rapid" change,
since actual syntax check is happening in the background.

=cut

sub refresh_syntax {
	my $self = shift;
	return unless $self->has_syntax;
	return if $self->locked('REFRESH');
	return unless $self->menu->view->{syntax}->IsChecked;
	$self->syntax->refresh( $_[0] or $self->current );
	return;
}

=pod

=head3 C<refresh_vcs>

    $main->refresh_vcs;

Do a refresh of version control checking. This is a "rapid" change,
since actual version control check is happening in the background.

=cut

sub refresh_vcs {
	my $self = shift;
	return unless $self->has_vcs;
	return if $self->locked('REFRESH');
	return unless $self->menu->view->{vcs}->IsChecked;
	$self->vcs->refresh( $_[0] or $self->current );
	return;
}


=pod

=head3 C<refresh_outline>

    $main->refresh_outline;

Force a refresh of the outline panel.

=cut

sub refresh_outline {
	my $self = shift;
	return unless $self->has_outline;
	return if $self->locked('REFRESH');
	return unless $self->menu->view->{outline}->IsChecked;
	$self->outline->refresh( $_[0] or $self->current );
	return;
}

=pod

=head3 C<refresh_menu>

    $main->refresh_menu;

Force a refresh of all menus. It can enable / disable menu entries
depending on current document or Padre internal state.

=cut

sub refresh_menu {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->menu->refresh;
}

=head3 C<refresh_menu_plugins>

    $main->refresh_menu_plugins;

Force a refresh of just the plug-in menus.

=cut

sub refresh_menu_plugins {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->menu->plugins->refresh($self);
}

=head2 C<refresh_notebook>

    $main->refresh_notebook

Force a refresh of the notebook panel titles

=cut

sub refresh_notebook {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->notebook->refresh;
}

=head3 C<refresh_windowlist>

    $main->refresh_windowlist

Force a refresh of the list of windows in the window menu

=cut

sub refresh_windowlist {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->menu->window->refresh_windowlist($self);
}

=pod

=head3 C<refresh_recent>

Specifically refresh the Recent Files entries in the File dialog

=cut

sub refresh_recent {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->menu->file->refresh_recent;
}

=pod

=head3 C<refresh_toolbar>

    $main->refresh_toolbar;

Force a refresh of Padre's toolbar.

=cut

sub refresh_toolbar {
	my $self = shift;
	return if $self->locked('REFRESH');
	my $toolbar = $self->GetToolBar or return;
	$toolbar->refresh( $_[0] or $self->current );
}

=pod

=head3 C<refresh_status>

    $main->refresh_status;

Force a refresh of Padre's status bar.

=cut

sub refresh_status {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->GetStatusBar->refresh( $_[0] or $self->current );
}

=pod

=head3 C<refresh_status_template>

    $main->refresh_status_templat;

Force a refresh of Padre's status bar. 
The part that is driven by a template.

=cut

sub refresh_status_template {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->GetStatusBar->refresh_from_template( $_[0] or $self->current );
}

=pod

=head3 C<refresh_cursorpos>

    $main->refresh_cursorpos;

Force a refresh of the position of the cursor on Padre's status bar.

=cut

sub refresh_cursorpos {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->GetStatusBar->update_pos( $_[0] or $self->current );
}

sub refresh_rdstatus {
	my $self = shift;
	return if $self->locked('REFRESH');
	$self->GetStatusBar->is_read_only( $_[0] or $self->current );
	return;
}

=pod

=head3 C<refresh_functions>

    $main->refresh_functions;

Force a refresh of the function list on the right.

=cut

sub refresh_functions {
	my $self = shift;
	return unless $self->has_functions;
	return if $self->locked('REFRESH');
	return unless $self->menu->view->{functions}->IsChecked;
	$self->functions->refresh( $_[0] or $self->current );
	return;
}

=pod

=head3 C<refresh_todo>

    $main->refresh_todo;

Force a refresh of the TODO list on the right.

=cut

sub refresh_todo {
	my $self = shift;
	return unless $self->has_todo;
	return if $self->locked('REFRESH');
	return unless $self->menu->view->{todo}->IsChecked;
	$self->todo->refresh( $self->current );
	return;
}

=pod

=head3 C<refresh_directory>

Force a refresh of the directory tree

=cut

sub refresh_directory {
	my $self = shift;
	return unless $self->has_directory;
	return if $self->locked('REFRESH');
	$self->directory->refresh( $_[0] or $self->current );
	return;
}

=pod

=head3 C<refresh_aui>

This is a refresh method wrapper around the C<AUI> C<Update> method so
that it can be lock-managed by the existing locking system.

=cut

sub refresh_aui {
	my $self = shift;
	return if $self->locked('refresh_aui');
	$self->aui->Update;
	return;
}

=pod

=head3 C<refresh_diff>

    $main->refresh_diff;

Do a refresh of saved and current document differences. This is a "rapid" change,
since actual calculating differences is happening in the background.

=cut

sub refresh_diff {
	my $self = shift;
	return unless Padre::Feature::DIFF_DOCUMENT;
	return if $self->locked('REFRESH');
	$self->diff->refresh( $_[0] or $self->current );
	return;
}

=pod

=head2 Interface Rebuilding Methods

Those methods reconfigure Padre's main window in case of drastic changes
(locale, etc.)

=head3 C<change_locale>

    $main->change_locale( $locale );

Change Padre's locale to C<$locale>. This will update the GUI to reflect
the new locale.

=cut

sub change_locale {
	my $self = shift;
	my $name = shift;
	my $lock = $self->lock('CONFIG');
	unless ( defined $name ) {
		$name = Padre::Locale::system_rfc4646 || Padre::Locale::last_resort_rfc4646;
	}
	TRACE("Changing locale to '$name'") if DEBUG;

	# Save the locale to the config
	$self->config->set( locale => $name );

	# Reset the locale
	delete $self->{locale};
	$self->{locale} = Padre::Locale::object();

	# Make WxWidgets translate the default buttons etc.
	if (Padre::Constant::UNIX) {
		## no critic (RequireLocalizedPunctuationVars)
		$ENV{LANGUAGE} = $name;
		## use critic
	}

	# Run the "relocale" process to update the GUI
	$self->relocale;

	# With language stuff updated, do a full refresh
	# sweep to clean everything up.
	$self->refresh;

	return;
}

=pod

=head3 C<relocale>

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

	# Relocale the plug-ins
	$self->ide->plugin_manager->relocale;

	# The menu doesn't support relocale, replace it
	# I wish this code didn't have to be so ugly, but we want to be
	# sure we clean up all the menu memory properly.
	SCOPE: {
		delete $self->{menu};
		$self->{menu} = Padre::Wx::Menubar->new($self);
		my $old = $self->GetMenuBar;
		$self->SetMenuBar( $self->menu->wx );
		$old->Destroy;
	}

	# Refresh the plugins' menu entries
	$self->refresh_menu_plugins;

	# The toolbar doesn't support relocale, replace it
	$self->rebuild_toolbar;

	# Cascade relocation to AUI elements and other tools
	$self->aui->relocale;
	$self->left->relocale      if $self->has_left;
	$self->right->relocale     if $self->has_right;
	$self->bottom->relocale    if $self->has_bottom;
	$self->directory->relocale if $self->has_directory;

	# Update the document titles (mostly for unnamed documents)
	$self->notebook->relocale;

	# Replace the regex editor, keep the data (if it exists)
	if ( exists $self->{regex_editor} ) {
		my $data_ref    = $self->{regex_editor}->get_data;
		my $was_visible = $self->{regex_editor}->Hide;

		$self->{regex_editor} = Padre::Wx::Dialog::RegexEditor->new($self);
		$self->{regex_editor}->show if $was_visible;
		$self->{regex_editor}->set_data($data_ref);
	}

	return;
}

=pod

=head3 C<restyle>

    $main->restyle;

The term and method C<restyle> is reserved for code that needs to be run when
the L<Padre::Wx::Theme|theme> of the editor has changed and the colouring of
the application needs to be changed without restarting.

Note that the new style must be applied to configuration before this method is
called, and this method is usually called by the C<apply> handler for the
C<editor_style> configuration setting.

=cut

sub restyle {
	my $self  = shift;
	my $name  = $self->config->editor_style;
	my $style = $self->{theme} = Padre::Wx::Theme->find($name);
	my $lock  = $self->lock('UPDATE');

	# Apply the new style to all current editors
	foreach my $editor ( $self->editors ) {
		$style->apply($editor);
	}

	return;
}

=pod

=head3 C<rebuild_toolbar>

    $main->rebuild_toolbar;

Destroy and rebuild the toolbar. This method is useful because the
toolbar is not really flexible, and most of the time it's better to
recreate it from scratch.

=cut

sub rebuild_toolbar {
	my $self    = shift;
	my $lock    = $self->lock('UPDATE');
	my $toolbar = $self->GetToolBar;
	$toolbar->Destroy if $toolbar;

	require Padre::Wx::ToolBar;
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

=head3 C<find_view>

    my $name = $main->find_view('Padre::Wx::FunctionList');

The C<find_view> method locates the name of the panel in which a tool is
currently being shown. We assume each tool is only being shown once.

Returns the name of the panel in string form (such as 'left') or false
if the view is not currently being shown.

=cut

sub find_view {
	my $self = shift;
	my $page = shift;
	foreach my $name ( PANELS ) {
		my $has = "has_$name";
		next unless $self->$has();
		my $panel = $self->$name();
		if ( $panel->GetPageIndex($page) >= 0 ) {
			return $name;
		}
	}
	return '';
}

=pod

=head3 C<show_view>

    $main->show_view( functions => 1 );

The C<show_view> methods displays or hides a named view of the main window.

=cut

sub show_view {
	my $self = shift;
	my $name = shift;
	my $show = shift;
	my $has  = "has_$name";

	if ( $show ) {
		my $config = $self->config;
		my $where  = "main_${name}_panel";
		my $lock   = $self->lock('UPDATE', 'AUI');
		my $page   = $self->$name();
		my $panel  = $config->can($where)
		           ? $config->$where()
		           : $page->view_panel;
		$self->$panel()->show($page);

	} elsif ( $self->$has() ) {
		my $page   = $self->$name();
		my $panel  = $self->find_view($page) or return;
		my $lock   = $self->lock('UPDATE', 'AUI');
		$self->$panel()->hide($page);
	}

	return;
}

=pod

=head3 C<show_functions>

    $main->show_functions( $visible );

Show the functions panel on the right if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_functions {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{functions};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG', 'refresh_functions' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_functions => $show );
	$self->show_view( functions => $show );
}

=pod

=head3 C<show_todo>

    $main->show_todo( $visible );

Show the I<to do> panel on the right if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_todo {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{todo};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG', 'refresh_todo' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_todo => $show );
	$self->show_view( todo => $show );
}

=pod

=head3 C<show_outline>

    $main->show_outline( $visible );

Show the outline panel on the right if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_outline {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{outline};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG', 'refresh_outline' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_outline => $show );
	$self->show_view( outline => $show );
}

=pod

=head3 C<show_debug>

    $main->show_debug($visible);

=cut

BEGIN {
	no warnings 'once';
	*show_debug = sub {
		my $self = shift;
		my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
		my $lock = $self->lock('UPDATE');
		$self->_show_debug($show);
		$self->aui->Update;
		return;
		}
		if Padre::Feature::DEBUGGER;

	*_show_debug = sub {
		my $self = shift;
		my $lock = $self->lock('UPDATE');
		if ( $_[0] ) {
			my $debugger = $self->debugger;
			$self->right->show($debugger);
		} elsif ( $self->has_debugger ) {
			my $debugger = $self->debugger;
			$self->right->hide($debugger);
		}
		return 1;
		}
		if Padre::Feature::DEBUGGER;
}

=pod

=head3 C<show_directory>

    $main->show_directory( $visible );

Show the directory panel on the right if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_directory {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{directory};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG', 'refresh_directory' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_directory => $show );
	$self->show_view( directory => $show );
}

=pod

=head3 C<show_output>

    $main->show_output( $visible );

Show the output panel at the bottom if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_output {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{output};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_output => $show );
	$self->show_view( output => $show );
}

=pod

=head3 C<show_findfast>

    $main->show_findfast( $visible );

Show the Fast Find panel at the bottom of the editor area if C<$visible> is
true. Hide it otherwise. If C<$visible> is not provided, the method defaults
to show the panel.

=cut

sub show_findfast {
	my $self    = shift;
	my $show    = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $visible = $self->has_findfast && $self->findfast->IsShown;
	if ( $show and not $visible ) {
		$self->findfast->show;
	} elsif ( $visible and not $show ) {
		$self->findfast->hide;
	}
	return;
}

=pod

=head3 C<show_foundinfiles>

    $main->show_foundinfiles( $visible );

Show the Find in Files panel at the bottom if C<$visible> is true.
Hide it otherwise. If C<$visible> is not provided, the method defaults
to show the panel.

=cut

sub show_foundinfiles {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $lock = $self->lock( 'UPDATE', 'AUI' );
	$self->show_view( foundinfiles => $show );
}

=pod

=head3 C<show_replaceinfiles>

    $main->show_replaceinfiles( $visible );

Show the Replace in Files panel at the bottom if C<$visible> is true.
Hide it otherwise. If C<$visible> is not provided, the method defaults
to show the panel.

=cut

sub show_replaceinfiles {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $lock = $self->lock( 'UPDATE', 'AUI' );
	$self->show_view( replaceinfiles => $show );
}

=pod

=head3 C<show_command>

    $main->show_command( $visible );

Show the command panel at the bottom if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_command {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{command};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_command => $show );
	$self->show_view( command => $show );
}

=pod

=head3 C<show_syntax>

    $main->show_syntax( $visible );

Show the syntax panel at the bottom if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_syntax {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{syntax};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG', 'refresh_syntax' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_syntax => $show );
	$self->show_view( syntax => $show );
}

=pod

=head3 C<show_vcs>

    $main->show_vcs( $visible );

Show the version control panel at the bottom if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_vcs {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{vcs};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG', 'refresh_vcs' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_vcs => $show );
	$self->show_view( vcs => $show );
	return;
}

=pod

=head3 C<show_cpan>

    $main->show_cpan( $visible );

Show the CPAN explorer panel at the bottom if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_cpan {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->view->{cpan};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_cpan => $show );
	$self->show_view( cpan => $show );
	return;
}

=pod

=head3 C<show_breakpoints>

    $main->show_breakpoints( $visible );

Show the version control panel at the left if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_breakpoints {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->debug->{breakpoints};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_breakpoints => $show );
	$self->show_view( breakpoints => $show );
}

=pod

=head3 C<show_debugoutput>

    $main->show_debugoutput( $visible );

Show the version control panel at the left if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_debugoutput {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->debug->{debugoutput};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_debugoutput => $show );
	$self->show_view( debugoutput => $show );
}

=pod

=head3 C<show_debugger>

    $main->show_debugger( $visible );

Show the version control panel at the left if C<$visible> is true. Hide it
otherwise. If C<$visible> is not provided, the method defaults to show
the panel.

=cut

sub show_debugger {
	my $self = shift;
	my $show = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
	my $item = $self->menu->debug->{debugger};
	my $lock = $self->lock( 'UPDATE', 'AUI', 'CONFIG' );
	$item->Check($show) unless $show == $item->IsChecked;
	$self->config->set( main_debugger => $show );
	$self->show_view( debugger => $show );
}

=pod

=head2 Introspection

The following methods allow to poke into Padre's internals.

=head3 C<current>

    my $current = $main->current;

Creates a L<Padre::Current> object for the main window, giving you quick
and caching access to the current various object members.

See L<Padre::Current> for more information.

=cut

sub current {
	Padre::Current->new( main => $_[0] );
}

=pod

=head3 C<pageids>

    my @ids = $main->pageids;

Return a list of all current tab ids (integers) within the notebook.

=cut

sub pageids {
	$_[0]->notebook->pageids;
}

=pod

=head3 C<editors>

    my @editors = $main->editors;

Return a list of all current editors. Those are the real objects, not
the ids (see C<pageids()> above).

Note: for now, this has the same meaning as C<pages()> (see above), but
this will change once we get project tabs or something else.

=cut

sub editors {
	$_[0]->notebook->editors;
}

=pod

=head3 C<documents>

    my @document = $main->documents;

Return a list of all current documents, in the specific order
they are open in the notebook.

=cut

sub documents {
	$_[0]->notebook->documents;
}

=pod

=head3 C<documents_modified>

Returns a list of all modified documents, in the specific order
they are open in the notebook.

=cut

sub documents_modified {
	grep { $_->is_modified } $_[0]->documents;
}

=pod

=head2 Process Execution

The following methods run an external command, for example to evaluate
current document.

=head3 C<on_run_command>

    $main->on_run_command;

Prompt the user for a command to run, then run it with C<run_command()>
(see below).

Note: it probably needs to be combined with C<run_command()> itself.

=cut

sub on_run_command {
	my $self = shift;

	require Padre::Wx::TextEntryDialog::History;
	my $dialog = Padre::Wx::TextEntryDialog::History->new(
		$self,
		Wx::gettext("Command line"),
		Wx::gettext("Run setup"),
		"run_command",
	);
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	my $command = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $command and $command ne '' ) {
		return;
	}
	$self->run_command($command);
	return;
}

=pod

=head3 C<on_run_tdd_tests>

   $main->on_run_tdd_tests;

Callback method, to build and then call on_run_tests

=cut

sub on_run_tdd_tests {
	my $self     = shift;
	my $document = $self->current->document;
	unless ($document) {
		return $self->error( Wx::gettext("No document open") );
	}

	# Find the project
	my $project_dir = $document->project_dir;
	unless ($project_dir) {
		return $self->error( Wx::gettext("Could not find project root") );
	}

	my $dir = Cwd::cwd;
	chdir $project_dir;

	# TODO maybe add save file(s) to this action?
	# TODO make this the user selected perl also
	# do it in Padre::Document::Perl::get_command
	my $perl = $self->config->run_perl_cmd;
	unless ($perl) {
		require Padre::Perl;
		$perl = Padre::Perl::cperl();
	}

	if ($perl) {
		if ( -e 'Build.PL' ) {
			$self->run_command("$perl Build.PL");
			$self->run_command("$perl Build test");
		} elsif ( -e 'Makefile.PL' ) {
			$self->run_command("$perl Makefile.PL");
			my $make = $Config::Config{make};
			$make = 'make' unless defined $make;
			$self->run_command("$make test");
		} elsif ( -e 'dist.ini' ) {
			$self->run_command("dzil test");
		} else {
			$self->error( Wx::gettext("No Build.PL nor Makefile.PL nor dist.ini found") );
		}
	} else {
		$self->error( Wx::gettext("Could not find perl executable") );
	}
	chdir $dir;
}

=pod

=head3 C<on_run_tests>

    $main->on_run_tests;

Callback method, to run the project tests and harness them.

=cut

sub on_run_tests {
	my $self     = shift;
	my $document = $self->current->document;
	unless ($document) {
		return $self->error( Wx::gettext("No document open") );
	}

	# TO DO probably should fetch the current project name
	my $filename = defined( $document->{file} ) ? $document->{file}->filename : undef;
	unless ($filename) {
		return $self->error( Wx::gettext("Current document has no filename") );
	}

	# Find the project
	my $project_dir = $document->project_dir;
	unless ($project_dir) {
		return $self->error( Wx::gettext("Could not find project root") );
	}

	my $dir = Cwd::cwd;
	chdir $project_dir;
	require File::Which;
	my $prove = File::Which::which('prove');
	if (Padre::Constant::WIN32) {

		# This is needed since prove does not work with path containing
		# spaces. Please see ticket:582
		require File::Glob::Windows;

		my $tempfile = File::Temp->new( UNLINK => 0 );
		print $tempfile join( "\n", File::Glob::Windows::glob("$project_dir/t/*.t") );
		close $tempfile;

		my $things_to_test = $tempfile->filename;
		$self->run_command(qq{"$prove" - -b < "$things_to_test"});
	} else {
		$self->run_command("$prove -l $project_dir/t");
	}
	chdir $dir;
}

=pod

=head3 C<on_run_this_test>

    $main->on_run_this_test;

Callback method, to run the currently open test through prove.

=cut

sub on_run_this_test {
	my $self     = shift;
	my $document = $self->current->document;
	unless ($document) {
		return $self->error( Wx::gettext("No document open") );
	}

	# TO DO probably should fetch the current project name
	my $filename = defined( $document->{file} ) ? $document->{file}->filename : undef;
	unless ($filename) {
		return $self->error( Wx::gettext("Current document has no filename") );
	}
	unless ( $filename =~ /\.t$/ ) {
		return $self->error( Wx::gettext("Current document is not a .t file") );
	}

	# Find the project
	my $project_dir = $document->project_dir;
	unless ($project_dir) {
		return $self->error( Wx::gettext("Could not find project root") );
	}

	my $dir = Cwd::cwd;
	chdir $project_dir;
	require File::Which;
	my $prove = File::Which::which('prove');
	if (Padre::Constant::WIN32) {

		# This is needed since prove does not work with path containing
		# spaces. Please see ticket:582
		my $tempfile = File::Temp->new( UNLINK => 0 );
		print $tempfile $filename;
		close $tempfile;

		my $things_to_test = $tempfile->filename;
		$self->run_command(qq{"$prove" - -lv < "$things_to_test"});
	} else {
		$self->run_command("$prove -lv $filename");
	}
	chdir $dir;
}

=pod

=head3 C<on_open_in_file_browser>

    $main->on_open_in_file_browser( $filename );

Opens the current C<$filename> using the operating system's file browser

=cut

sub on_open_in_file_browser {
	my ( $self, $filename ) = @_;

	require Padre::Util::FileBrowser;
	Padre::Util::FileBrowser->open_in_file_browser($filename);
}

=pod

=head3 C<run_command>

    $main->run_command( $command );

Run C<$command> and display the result in the output panel.

=cut

sub run_command {
	my $self = shift;
	my $cmd  = shift;

	# when this mode is used the Run menu options are not turned off
	# and the Run/Stop is not turned on as we currently cannot control
	# the external execution.
	my $config = $self->config;
	if ( $config->run_use_external_window ) {
		if (Padre::Constant::WIN32) {
			my $title = $cmd;
			$title =~ s/"//g;
			system qq(start "$title" cmd /C "$cmd & pause");
		} elsif (Padre::Constant::UNIX) {

			if ( defined $ENV{COLORTERM} ) {
				if ( $ENV{COLORTERM} eq 'gnome-terminal' ) {

					#Gnome-Terminal line format:
					#gnome-terminal -e "bash -c \"prove -lv t/96_edit_patch.t; exec bash\""
					system qq($ENV{COLORTERM} -e "bash -c \\\"$cmd; exec bash\\\"" & );
				} else {
					system qq(xterm -sb -e "$cmd; sleep 1000" &);
				}
			}
		} elsif (Padre::Constant::UNIX) {

			# tome
		} else {
			system qq(xterm -sb -e "$cmd; sleep 1000" &);
		}
		return;
	}

	# Disable access to the run menus
	$self->menu->run->disable;

	# Prepare the output window for the output
	$self->show_output(1);
	$self->output->Remove( 0, $self->output->GetLastPosition );

	# ticket #205, reset output style to neutral
	$self->output->style_neutral;

	# If this is the first time a command has been run,
	# set up the ProcessStream bindings.
	unless ($Wx::Perl::ProcessStream::VERSION) {
		require Wx::Perl::ProcessStream;
		if ( $Wx::Perl::ProcessStream::VERSION < .25 ) {
			$self->error(
				sprintf(
					Wx::gettext(
						      'Wx::Perl::ProcessStream is version %s'
							. ' which is known to cause problems. Get at least 0.20 by typing'
							. "\ncpan Wx::Perl::ProcessStream"
					),
					$Wx::Perl::ProcessStream::VERSION
				)
			);
			return 1;
		}

		# This is needed to avoid Padre from freezing/hanging when
		# running print-intensive scripts like the following:
		# 		while(1) { warn "FREEZE"; };
		# See ticket:863 "Continous warnings or prints kill Padre"
		Wx::Perl::ProcessStream->SetDefaultMaxLines(100);

		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDOUT(
			$self,
			sub {
				$_[1]->Skip(1);
				my $outpanel = $_[0]->output;
				$outpanel->style_neutral;

				# NOTE: ticket 1007 happens if we do
				# $outpanel->AppendText( $_[1]->GetLine . "\n" );
				# if, however, we do the following, we empty the
				# entire buffer and the bug completely goes away.
				my $out = join "\n", @{ $_[1]->GetProcess->GetStdOutBuffer };

				# NOTE: also, ProcessStream seems to call this sub on every
				# "\n", but since the buffer is already empty, it just prints
				# our own linebreak. This means if a text has lots of "\n",
				# we'll get tons of empty lines at the end of the panel.
				# Please fix this if you can, but make sure ticket 1007 doesn't
				# happen again. Also remember to repeat the fix for STDERR below
				$outpanel->AppendText( $out . "\n" ) if $out;
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDERR(
			$self,
			sub {
				$_[1]->Skip(1);
				my $outpanel = $_[0]->output;
				$outpanel->style_bad;

				# NOTE: ticket 1007 happens if we do
				# $outpanel->AppendText( $_[1]->GetLine . "\n" );
				# if, however, we do the following, we empty the
				# entire buffer and the bug completely goes away.
				my $errors = join "\n", @{ $_[1]->GetProcess->GetStdErrBuffer };
				$outpanel->AppendText( $errors . "\n" ) if $errors;

				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_EXIT(
			$self,
			sub {
				$_[1]->Skip(1);
				$_[1]->GetProcess->Destroy;
				delete $self->{command};
				$self->menu->run->enable;
			},
		);
	}

	# Start the command
	my $process = Wx::Perl::ProcessStream::Process->new( $cmd, "Run $cmd", $self );
	$self->{command} = $process->Run;

	# Check if we started the process or not
	unless ( $self->{command} ) {

		# Failed to start the command. Clean up.
		$self->error( sprintf( Wx::gettext("Failed to start '%s' command"), $cmd ) );
		$self->menu->run->enable;
	}
	$self->current->editor->SetFocus;
	return;
}

=pod

=head3 C<run_document>

    $main->run_document( $debug )

Run current document. If C<$debug> is true, document will be run with
diagnostics and various debug options.

Note: this should really be somewhere else, but can stay here for now.

=cut

sub run_document {
	my $self     = shift;
	my $trace    = shift;
	my $document = $self->current->document;
	unless ($document) {
		return $self->error( Wx::gettext("No open document") );
	}

	# Apply the user's save-on-run policy
	# TO DO: Make this code suck less
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
		return $self->error(
			Wx::gettext('No execution mode was defined for this document type') . ': ' . $document->mimetype );
	}

	my $cmd = eval { $document->get_command( { $trace ? ( trace => 1 ) : () } ) };
	if ($@) {
		chomp $@;
		$self->error($@);
		return;
	}
	if ($cmd) {
		if ( $document->pre_process ) {
			SCOPE: {
				require File::pushd;

				# Ticket #845 this project_dir is created in correctly when you do padre somedir/script.pl and run F5 on that
				# real stupid think so we don't crash
				# to fix this $document->get_command needs to recognize which folder it is in
				# The other part of this fix is in lib/Padre/Document/Perl.pm in get_command
				# Please feel free to fix this
				File::pushd::pushd( $document->project_dir ) if -e $document->project_dir;
				$self->run_command($cmd);
			}
		} else {
			my $styles = Wx::CENTRE | Wx::ICON_HAND | Wx::YES_NO;
			my $ret    = Wx::MessageBox(
				$document->errstr . "\n" . Wx::gettext('Do you want to continue?'),
				Wx::gettext("Warning"),
				$styles,
				$self,
			);
			if ( $ret == Wx::YES ) {
				SCOPE: {
					require File::pushd;
					File::pushd::pushd( $document->project_dir ) if -e $document->project_dir;
					$self->run_command($cmd);
				}
			}
		}
	}
	return;
}


=pod

=head2 Session Support

Those methods deal with Padre sessions. A session is a set of files /
tabs opened, with the position within the files saved, as well as the
document that has the focus.

=head3 C<capture_session>

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

=head3 C<open_session>

    $main->open_session( $session );

Try to close all files, then open all files referenced in the given
C<$session> (a C<Padre::DB::Session> object). No return value.

=cut

sub open_session {
	my $self     = shift;
	my $session  = shift;
	my $autosave = shift || 0;

	# Are there any files in the session?
	my @files = $session->files or return;

	# Prevent redrawing until we're done
	my $lock = $self->lock( 'UPDATE', 'DB', 'refresh' );

	# Progress dialog for the session changes
	require Padre::Wx::Progress;
	my $progress = Padre::Wx::Progress->new(
		$self,
		sprintf(
			Wx::gettext('Opening session %s...'),
			$session->name,
		),
		$#files + 1,
		lazy => 1
	);

	# Close all files
	# This takes some time, so do it after the progress dialog was displayed
	$self->close_all;

	# opening documents
	my $focus    = undef;
	my $notebook = $self->notebook;
	foreach my $file_no ( 0 .. $#files ) {
		my $document = $files[$file_no];
		$progress->update( $file_no, $document->file );
		TRACE( "Opening '" . $document->file . "' for $document" ) if DEBUG;
		my $filename = $document->file;
		require Padre::File;
		my $file = Padre::File->new($filename);
		next unless defined($file);
		next unless $file->exists;
		my $id = $self->setup_editor($filename);
		next unless $id; # documents already opened have undef $id
		TRACE("Setting focus on $filename") if DEBUG;
		$focus = $id if $document->focus;
		$notebook->GetPage($id)->goto_pos_centerize( $document->position );
	}

	$progress->update( $#files + 1, Wx::gettext('Restore focus...') );
	$self->on_nth_pane($focus) if defined $focus;

	$self->ide->{session}          = $session->id;
	$self->ide->{session_autosave} = $autosave;

	return 1;
}

=pod

=head3 C<save_session>

    $main->save_session( $session, @session );

Try to save C<@session> files (C<Padre::DB::SessionFile> objects, such
as what is returned by C<capture_session()> - see above) to database,
associated to C<$session>. Note that C<$session> should already exist.

=cut

sub save_session {
	my ( $self, $session, @session ) = @_;

	my $transaction = $self->lock('DB');
	foreach my $file (@session) {
		$file->set( session => $session->id );
		$file->insert;
	}

	Padre::DB->do( 'UPDATE session SET last_update=? WHERE id=?', {}, time, $session->id );

}

sub save_current_session {
	my $self = shift;

	return if not $self->ide->{session_autosave};

	my ($session) = Padre::DB::Session->select(
		'where id = ?',
		$self->{ide}->{session}
	);

	$session ||= Padre::DB::Session->last_padre_session;

	if ( not defined $session ) {

		# TO DO: maybe report an error here?
		return;
	}

	# session exist, remove all files associated to it
	Padre::DB::SessionFile->delete(
		'where session = ?',
		$session->id
	);

	# capture session and save it
	my @session = $self->capture_session;
	$self->save_session( $session, @session );

	return;
}

=pod

=head2 User Interaction

Various methods to help send information to user.

Some methods are inherited from L<Padre::Wx::Role::Dialog>.

=head3 C<status>

    $main->status($msg);

Temporarily change the status bar leftmost block only to some message.

This is a super-quick method intended for transient messages as short
as a few tens of milliseconds (for example printing all directories
read during a recursive file scan).

=cut

sub status {
	$_[0]->GetStatusBar->say( $_[1] );
}

=head3 C<info>

    $main->info($msg);

Print a message on the status bar or within a dialog box depending on the
users preferences setting.

The dialog has only a OK button and there is no return value.

=cut

sub info {
	my $self = shift;

	unless ( $self->config->info_on_statusbar ) {
		return $self->message(@_);
	}

	my $message = shift;
	$message =~ s/[\r\n]+/ /g;
	$self->{infomessage}         = $message;
	$self->{infomessage_timeout} = time + 10;
	$self->refresh_status;
	return;
}

=pod

=head3 C<prompt>

    my $value = $main->prompt( $title, $subtitle, $key );

Prompt user with a dialog box about the value that C<$key> should have.
Return this value, or C<undef> if user clicked C<cancel>.

=cut

sub prompt {
	my $self     = shift;
	my $title    = shift || "Prompt";
	my $subtitle = shift || "Subtitle";
	my $key      = shift || "GENERIC";

	require Padre::Wx::TextEntryDialog::History;
	my $dialog = Padre::Wx::TextEntryDialog::History->new(
		$self, $title, $subtitle, $key,
	);
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	my $value = $dialog->GetValue;
	$dialog->Destroy;
	return $value;
}

=head3 C<simple_prompt>

    my $value = $main->simple_prompt( $title, $subtitle, $default_text );

Prompt user with a dialog box about the value that C<$key> should have.
Return this value, or C<undef> if user clicked C<cancel>.

=cut

sub simple_prompt {
	my $self     = shift;
	my $title    = shift || 'Prompt';
	my $subtitle = shift || 'Subtitle';
	my $value    = shift || '';

	my $dialog = Wx::TextEntryDialog->new( $self, $title, $subtitle, $value );
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	my $new_value = $dialog->GetValue;
	return $new_value;
}

=pod

=head2 Search and Replace

These methods provide the highest level abstraction for entry into the various
search and replace functions and dialogs.

However, they still represent abstract logic and should NOT be tied directly to
keystroke or menu events.

=head3 C<find_dialog>

    $main->find_dialog;

Show the find dialog, escalating from the fast find if needed

=cut

sub find_dialog {
	my $self = shift;
	my $term = '';

	# Close the fast find panel if it was open
	if ( $self->has_findfast ) {

	}

	# Create the find dialog.
	my $find = $self->find;


}

=pod

=head3 C<search_next>

  # Next match for a new explicit search
  $main->search_next( $search );

  # Next match on current search
  $main->search_next;

Find the next match for the current search.

If no files are open, silently do nothing (don't even remember the new search)

=cut

sub search_next {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	my $search = $self->search;

	# If we are passed an explicit search object,
	# shortcut special logic and run that search immediately.
	if ( Params::Util::_INSTANCE( $_[0], 'Padre::Search' ) ) {
		$search = $self->{search} = shift;
		return !!$search->search_next($editor);
	} elsif (@_) {
		die 'Invalid argument to search_next';
	}

	# Handle the obvious case with nothing selected
	my ( $position1, $position2 ) = $editor->GetSelection;
	if ( $position1 == $position2 ) {
		return unless $search;
		return !!$search->search_next($editor);
	}

	# If we have an active search and the current selection
	# matches it in it's entirety, then we run the current search
	# again and don't make a new one.
	# NOTE: This will fail for a number of regex cases, but is better then
	# not doing a check like this at all. Upgrade it later.
	my $matched = $editor->matched;
	if ( $search and $matched and $search->equals( $matched->[0] ) ) {
		if ( $matched->[1] == $position1 and $matched->[2] == $position2 ) {
			# Continue the existing search from the end of the match
			$editor->SetSelection( $position2, $position2 );
			return !!$search->search_next($editor);
		}
	}

	# For multiple lines we search for the first match inside of the range
	my $line1 = $editor->LineFromPosition($position1);
	my $line2 = $editor->LineFromPosition($position2);
	unless ( $line1 == $line2 ) {
		return unless $search;
		return !!$search->search_next($editor);
	}

	# Case-specific search for the current selection
	require Padre::Search;
	$search = $self->{search} = Padre::Search->new(
		find_case    => 1,
		find_regex   => 0,
		find_reverse => 0,
		find_term    => $editor->GetTextRange(
			$position1, $position2,
		),
	);
	return !!$search->search_next($editor);
}

=pod

=head3 C<search_previous>

  # Previous match for a new search
  $main->search_previous( $search );

  # Previous match on current search (or show Find dialog if none)
  $main->search_previous;

Find the previous match for the current search, or spawn the Find dialog.

If no files are open, do nothing.

=cut

sub search_previous {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	my $search = $self->search;

	# If we are passed an explicit search object,
	# shortcut special logic and run that search immediately.
	if ( Params::Util::_INSTANCE( $_[0], 'Padre::Search' ) ) {
		$search = $self->{search} = shift;
		return !!$search->search_previous($editor);
	} elsif (@_) {
		die 'Invalid argument to search_previous';
	}

	# Handle the obvious case with nothing selected
	my ( $position1, $position2 ) = $editor->GetSelection;
	if ( $position1 == $position2 ) {
		return unless $search;
		return !!$search->search_previous($editor);
	}

	# Multiple lines are also done the obvious way
	my $line1 = $editor->LineFromPosition($position1);
	my $line2 = $editor->LineFromPosition($position2);
	unless ( $line1 == $line2 ) {
		return unless $search;
		return !!$self->search_previous($editor);
	}

	# Case-specific search for the current selection
	require Padre::Search;
	$search = $self->{search} = Padre::Search->new(
		find_case    => 1,
		find_regex   => 0,
		find_reverse => 0,
		find_term    => $editor->GetTextRange(
			$position1, $position2,
		),
	);
	return !!$search->search_previous($editor);
}

=pod

=head3 C<replace_next>

  # Next replace for a new search
  $main->replace_next( $search );

  # Next replace on current search (or show Find dialog if none)
  $main->replace_next;

Replace the next match for the current search, or spawn the Replace dialog.

If no files are open, do nothing.

=cut

sub replace_next {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	if ( Params::Util::_INSTANCE( $_[0], 'Padre::Search' ) ) {
		$self->{search} = shift;
	} elsif (@_) {
		die "Invalid argument to replace_next";
	}

	# Replace if we can
	my $search = $self->search or return;
	$search->replace_next($editor);
}

=pod

=head3 C<replace_all>

  # Replace all for a new search
  $main->replace_all( $search );

  # Replace all for the current search (or show Replace dialog if none)
  $main->replace_all;

Replace all matches for the current search, or spawn the Replace dialog.

If no files are open, do nothing.

=cut

sub replace_all {
	my $self = shift;
	my $editor = $self->current->editor or return;
	if ( Params::Util::_INSTANCE( $_[0], 'Padre::Search' ) ) {
		$self->{search} = shift;
	} elsif (@_) {
		die("Invalid argument to replace_all");
	}

	# Replace if we can
	my $search = $self->search or return;
	$search->replace_all($editor);
}

=pod

=head2 General Events

Those methods are the various callbacks registered in the menus or
whatever widgets Padre has.

=head3 C<on_brace_matching>

    $main->on_brace_matching;

Jump to brace matching current the one at current position.

=cut

sub on_brace_matching {
	shift->current->editor->goto_matching_brace;
}

sub comment_toggle {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	$editor->comment_toggle;
}

sub comment_indent {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	$editor->comment_indent;
}

sub comment_outdent {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	$editor->comment_outdent;
}

=pod

=head3 C<on_autocompletion>

    $main->on_autocompletion;

Try to auto complete current word being typed, depending on
document type.

=cut

sub on_autocompletion {
	my $self     = shift;
	my $event    = shift;
	my $document = $self->current->document or return;

	my ( $length, @words ) = $document->autocomplete($event);

	# Nothing to show --> early exit
	return if !defined($length);
	return if $#words == -1;

	if ( $length =~ /\D/ ) {
		$self->message( $length, Wx::gettext("Autocompletion error") );
	}
	if (@words) {
		my $ide    = $self->ide;
		my $config = $ide->config;
		my $editor = $document->editor;

		$editor->AutoCompSetChooseSingle( $config->autocomplete_always ? 0 : 1 );
		$editor->AutoCompSetSeparator( ord ' ' );

		$editor->AutoCompShow( $length, join " ", @words );

		# Cancel the auto completion list when Padre loses focus
		Wx::Event::EVT_KILL_FOCUS(
			$editor,
			sub {
				my ( $self, $event ) = @_;
				unless ( $event->GetWindow ) {
					$editor->AutoCompCancel;
				}
			}
		);

	}
	return;
}

=head3 C<on_activate>

The C<on_activate> method is called when Padre has been in the background
for some period of time, and has just returned to the foreground.

It calls a subset of refresh methods where something may have been changed
by the user while they were using some other program that wasn't Padre.

=cut

sub on_activate {
	TRACE( $_[0] ) if DEBUG;
	my $self    = shift;
	my $current = $self->current;

	# The file system may have changed, refresh the directory list
	# and recompile the foreground file.
	$self->refresh_directory($current);
	$self->refresh_diff($current);
	$self->refresh_syntax($current);

	# They may be using an external VCS tool
	if (Padre::Feature::VCS) {
		$self->refresh_vcs($current);
	}

	# Ensure we are focused on the current document
	$self->editor_focus;

	return 1;
}

=head3 C<on_deactivate>

The C<on_deactivate> method is called when the user has switched away from
Padre to some other application.

Currently all this does is hide away from short-lived tools like Fast Find
if they are open, so that when the user returns it is not to a stale
UI context.

=cut

sub on_deactivate {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Hide the Find Fast panel if it is showing
	$self->show_findfast(0);

	return 1;
}

=pod

=head3 C<on_close_window>

Callback when window is about to be closed. This is our last chance to
veto the C<$event> close, e.g. when some files are not yet saved.

If close is confirmed, save configuration to disk. Also, capture current
session to be able to restore it next time if user set Padre to open
last session on start-up. Clean up all Task Manager's tasks.

=cut

sub on_close_window {
	my $self   = shift;
	my $event  = shift;
	my $ide    = $self->ide;
	my $config = $ide->config;

	TRACE("on_close_window") if DEBUG;

	# Terminate any currently running debugger session before we start
	# to do anything significant.
	if (Padre::Feature::DEBUGGER) {
		if ( $self->{debugger} ) {
			$self->{debugger}->quit;
		}
	}

	# Wrap one big database transaction around this entire shutdown process.
	# If the user aborts the shutdown, then the resulting commit will
	# just save some basic parts like the last session and so on.
	# Some of the steps in the shutdown have transactions anyway, but
	# this will expand them to cover everything.
	my $transaction = $self->lock( 'DB', 'refresh_recent' );

	# Capture the current session, before we start the interactive
	# part of the shutdown which will mess it up.
	$self->update_last_session;

	TRACE("went over list of files") if DEBUG;

	# Check that all files have been saved
	if ( $event->CanVeto ) {
		if ( $config->startup_files eq 'same' ) {

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

		# Make sure the user is aware of any rogue processes he might have ran
		if ( $self->{command} ) {
			my $ret = Wx::MessageBox(
				Wx::gettext("You still have a running process. Do you want to kill it and exit?"),
				Wx::gettext("Warning"),
				Wx::YES_NO | Wx::CENTRE,
				$self,
			);

			if ( $ret == Wx::YES ) {
				if ( $self->{command} ) {
					if (Padre::Constant::WIN32) {
						$self->{command}->KillProcess;
					} else {
						$self->{command}->TerminateProcess;
					}
					delete $self->{command};
				}
			} else {
				$event->Veto;
				return;
			}
		}
	}

	TRACE("Files saved (or not), hiding window") if DEBUG;

	# A number of things don't like being destroyed while they are locked.
	# Potential segfaults and what not. Instructing the locker to shutdown
	# will make it release all locks and silently suppress all attempts to
	# make new locks.
	$self->locker->shutdown;

	# Save the window geometry before we hide the window. There's some
	# weak evidence that capturing position while not showing might be
	# flaky in some situations, and this is pretty cheap so doing it before
	# (rather than after) the ->Show(0) shouldn't hurt much.
	$self->window_save;

	# Hide the window before any of the following slow/intensive stuff so
	# that the user perceives the application as closing faster. This knocks
	# at least quarter of a second off the speed at which Padre appears to
	# close compared to letting it close naturally.
	# It probably also makes it shut actually faster as well, as Wx won't
	# try to do any updates or painting as we shut things down.
	$self->Show(0);
	TRACE("MAIN WINDOW HIDDEN. PADRE APPEARS TO BE CLOSED TO USER") if DEBUG;

	# Clean up our secondary windows
	if ( $self->has_directory ) {
		$self->directory->view_stop;
	}
	if ( $self->has_functions ) {
		$self->functions->view_stop;
	}
	if ( $self->has_outline ) {
		$self->outline->view_stop;
	}
	if ( $self->has_syntax ) {
		$self->syntax->view_stop;
	}
	if ( $self->has_cpan ) {
		$self->cpan->view_stop;
	}
	if ( $self->has_vcs ) {
		$self->vcs->view_stop;
	}
	if ( $self->{help} ) {
		$self->{help}->Destroy;
	}

	# Shut down and destroy all the plug-ins before saving the
	# configuration so that plug-ins have a change to save their
	# configuration.
	$ide->plugin_manager->shutdown;
	TRACE("After plugin manager shutdown") if DEBUG;

	# Increment the startup counter now, so that it is higher next time
	$config->set( nth_startup => $config->nth_startup + 1 );

	# Write the configuration to disk
	$ide->save_config;
	$event->Skip(1);

	# Stop the task manager.
	TRACE("Shutting down Task Manager") if DEBUG;
	$ide->task_manager->stop;

	# The AUI manager requires a manual UnInit. The documentation for it
	# says that if we don't do this it may segfault the process on exit.
	$self->aui->UnInit;

	# Vacuum database on exit so that it does not grow.
	# Since you can't VACUUM inside a transaction, end it first.
	# Doing the vacuum here, which can take several 10ths of a second,
	# gives the child threads a chance to clean up and exit.
	undef $transaction;
	Padre::DB->vacuum;

	# Yield to allow any final task manager messages to flush out
	TRACE("Yielding to allow final plthreadevent handling") if DEBUG;
	$ide->wx->Yield;

	# Clean up the shut down (unjoined) threads
	TRACE("Waiting to join final threads") if DEBUG;
	$ide->task_manager->waitjoin;

	TRACE("Closing Padre") if DEBUG;
	return;
}

sub update_last_session {
	my $self = shift;

	# Only save if the user cares about sessions
	my $startup_files = $self->config->startup_files;
	unless ( $startup_files eq 'last' or $startup_files eq 'session' ) {
		return;
	}

	# Write the current session to the database
	my $transaction = $self->lock('DB');
	my $session     = Padre::DB::Session->last_padre_session;
	Padre::DB::SessionFile->delete( 'where session = ?', $session->id );
	$self->save_session( $session, $self->capture_session );
}

=pod

=head3 C<setup_editors>

    $main->setup_editors( @files );

Setup (new) tabs for C<@files>, and update the GUI. If C<@files> is C<undef>, open
an empty document.

=cut

sub setup_editors {
	my $self  = shift;
	my @files = @_;
	TRACE("setup_editors @files") if DEBUG;
	SCOPE: {

		# Update the menus AFTER the initial GUI update,
		# because it makes file loading LOOK faster.
		# Do the menu/etc refresh in the time it takes the
		# user to actually perceive the file has been opened.
		# Lock both Perl and Wx-level updates, and throw in a
		# database transaction for good measure.
		my $lock = $self->lock( 'UPDATE', 'DB', 'refresh', 'update_last_session' );

		# If and only if there is only one current file,
		# and it is unused, close it. This is a somewhat
		# subtle interface DWIM trick, but it's one that
		# clearly looks wrong when we DON'T do it.
		if ( $self->notebook->GetPageCount == 1 ) {
			if ( $self->current->document->is_unused ) {
				$self->close;
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

	my $manager = $self->{ide}->plugin_manager;
	$manager->plugin_event('editor_changed');

	return;
}

=pod

=head3 C<on_new>

    $main->on_new;

Create a new empty tab. No return value.

=cut

sub on_new {
	my $self = shift;
	my $lock = $self->lock( 'UPDATE', 'refresh' );
	$self->setup_editor;
	return;
}

=pod

=head3 C<setup_editor>

    $main->setup_editor( $file );

Setup a new tab / buffer and open C<$file>, then update the GUI. Recycle
current buffer if there's only one empty tab currently opened. If C<$file> is
already opened, focus on the tab displaying it. Finally, if C<$file> does not
exist, create an empty file before opening it.

=cut

sub setup_editor {
	my $self    = shift;
	my $file    = shift;
	my $ide     = $self->ide;
	my $config  = $ide->config;
	my $plugins = $ide->plugin_manager;

	TRACE( "setup_editor called for '" . ( $file || '' ) . "'" ) if DEBUG;

	if ($file) {

		# Get the absolute path
		# Please Dont use Cwd::realpath, UNC paths do not work on win32)
		# 	$file = File::Spec->rel2abs($file) if -f $file; # Mixes up URLs

		# Use Padre::File to get the real filenames
		require Padre::File;
		my $file_obj = Padre::File->new($file);
		if ( defined($file_obj) and ref($file_obj) and $file_obj->exists ) {
			my $id = $self->editor_of_file( $file_obj->{filename} );
			if ( defined $id ) {
				$self->on_nth_pane($id);
				return;
			}
		}

		#not sure where the best place for this checking is..
		#I'd actually like to make it recursivly open files
		#(but that will require a dialog listing them to avoid opening an infinite number of files)
		# WARNING: This currently only works on local files!
		if ( -d $file_obj->{filename} ) {
			$self->error(
				sprintf(
					Wx::gettext("Cannot open a directory: %s"),
					$file
				)
			);
			return;
		}
	}

	require Padre::Document;
	my $document = Padre::Document->new( filename => $file ) or return;
	$file ||= ''; # to avoid warnings
	if ( $document->errstr ) {
		warn $document->errstr . " when trying to open '$file'";
		return;
	}

	TRACE("Document created for '$file'") if DEBUG;

	require Padre::Wx::Editor;
	my $lock = $self->lock( 'REFRESH', 'update_last_session', 'refresh_menu' );
	my $editor = Padre::Wx::Editor->new( $self->notebook );
	$editor->{Document} = $document;
	$document->set_editor($editor);
	$editor->set_document($document);
	$plugins->editor_enable($editor);
	$editor->setup_document;

	if ( $document->is_new ) {

		# The project is probably the same as the previous file we had open
		$document->{project_dir} =
			  $self->current->document
			? $self->current->document->project_dir
			: $config->default_projects_directory;
	} else {
		TRACE( "Adding new file to history: " . $document->filename ) if DEBUG;

		my $history = $self->lock( 'DB', 'refresh_recent' );
		Padre::DB::History->create(
			type => 'files',
			name => $document->filename,
		);
	}

	my $title = $editor->{Document}->get_title;
	my $id = $self->create_tab( $editor, $title );
	$editor->Show;
	$self->notebook->GetPage($id)->SetFocus;

	if (Padre::Feature::CURSORMEMORY) {
		$editor->restore_cursor_position;
	}

	# Notify plugins
	$plugins->plugin_event('editor_changed');

	return $id;
}

=pod

=head3 C<create_tab>

    my $tab = $main->create_tab;

Create a new tab in the notebook, and return its id (an integer).

=cut

sub create_tab {
	my $self   = shift;
	my $editor = shift;
	my $title  = shift;
	$title ||= '(' . Wx::gettext('Unknown') . ')';

	my $lock = $self->lock('refresh');
	$self->notebook->AddPage( $editor, $title, 1 );
	$editor->SetFocus;
	return $self->notebook->GetSelection;
}

=pod

=head3 C<on_deparse>

Show what perl thinks about your code using L<B::Deparse>

=cut

sub on_deparse {
	my $self    = shift;
	my $current = $self->current;
	my $text    = shift || $current->text;
	my $editor  = $current->editor or return;

	# get selection, ask for it if needed
	unless ( length $text ) {
		$self->error('Currently we require a selection for this to work');
		return;
	}
	use Capture::Tiny qw(capture);

	my $dir = File::Temp::tempdir( CLEANUP => 1 );
	my $file = "$dir/file";
	if ( open my $fh, '>', $file ) {
		print $fh $text;
		close $fh;
	} else {
		$self->error('Strange error occured');
		return;
	}
	my $perl = $^X;

	my ( $out, $err ) = capture {
		system qq{$perl -MO=Deparse,-p $file};
	};

	if ($out) {
		$self->message( $out, 'Deparse' );
	} else {
		$self->error( 'Deparse failed: ' . $err );
	}

	# eg, highlight the code part of the following comment:
	# print ~~ grep { $_ eq 'x' } qw(a b c x);

	return;
}


=pod

=head3 C<on_open_selection>

    $main->on_open_selection;

Try to open current selection in a new tab. Different combinations are
tried in order: as full path, as path relative to C<cwd> (where the editor
was started), as path to relative to where the current file is, if we
are in a Perl file or Perl environment also try if the thing might be a
name of a module and try to open it locally or from C<@INC>.

No return value.

=cut

sub on_open_selection {
	my $self    = shift;
	my $current = $self->current;
	my $text    = shift || $current->text;
	my $editor  = $current->editor or return;

	# get selection, ask for it if needed
	unless ( length $text ) {
		my $dialog = Wx::TextEntryDialog->new(
			$self,
			Wx::gettext("Nothing selected. Enter what should be opened:"),
			Wx::gettext("Open selection"), ''
		);
		return if $dialog->ShowModal == Wx::ID_CANCEL;

		$text = $dialog->GetValue;
		$dialog->Destroy;
		return unless length $text;
	}

	# Remove leading and trailing whitespace or newlines
	# We assume you are opening _one_ file, so newlines in the middle are significant
	$text =~ s/^[\s\n]*(.*?)[\s\n]*$/$1/;

	my @files;
	if ( File::Spec->file_name_is_absolute($text) and -e $text ) {
		push @files, $text;
	} else {

		# Try relative to the dir we started in?
		SCOPE: {
			my $filename = File::Spec->catfile( $self->ide->{original_cwd}, $text, );
			if ( -f $filename ) {
				push @files, $filename;
			}
		}

		# Try relative to the current file
		if ( $current->filename ) {
			my $filename = File::Spec->catfile( File::Basename::dirname( $current->filename ), $text, );
			if ( -f $filename ) {
				push @files, $filename;
			}
		}
	}
	unless (@files) {
		my $document = $current->document;
		push @files, $document->guess_filename_to_open($text);
	}

	unless (@files) {
		$self->message(
			sprintf( Wx::gettext("Could not find file '%s'"), $text ),
			Wx::gettext("Open Selection")
		);
		return;
	}

	require List::MoreUtils;
	@files = List::MoreUtils::uniq(@files);
	if ( @files > 1 ) {

		# Pick a file
		my $file = $self->single_choice(
			Wx::gettext('Choose File'),
			'',
			[@files],
		);
		$self->setup_editors($file) if defined $file;
	} else {

		# Open the only result without further interaction
		$self->setup_editors( $files[0] );
	}

	return;
}

=pod

=head3 C<on_open_all_recent_files>

    $main->on_open_all_recent_files;

Try to open all recent files within Padre. No return value.

=cut

sub on_open_all_recent_files {
	my $files = Padre::DB::History->recent('files');

	# debatable: "reverse" keeps order in "recent files" submenu
	# but editor tab ordering may "feel" wrong
	$_[0]->setup_editors( reverse grep { -e $_ } @$files );
}

=pod

=head3 C<on_filter_tool>

    $main->on_filter_tool;

Prompt user for a command to filter the selection/document.

=cut

sub on_filter_tool {
	require Padre::Wx::Dialog::FilterTool;
	Padre::Wx::Dialog::FilterTool->new( $_[0] )->show;
}

=head3 C<on_open_url>

    $main->on_open_url;

Prompt user for URL to open and open it as a new tab.

Should be merged with ->on_open or at least a browsing function
should be added.

=cut

sub on_open_url {
	require Padre::Wx::Dialog::OpenURL;
	my $self = shift;
	my $url  = Padre::Wx::Dialog::OpenURL->modal($self);
	unless ( defined $url ) {
		return;
	}
	$self->setup_editor($url);

	$self->save_current_session;

}

=pod

=head3 C<on_open>

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
	$self->open_file_dialog;
}

# TO DO: let's allow this to be used by plug-ins
sub open_file_dialog {
	my $self = shift;
	my $dir  = shift;

	if ($dir) {
		$self->{cwd} = $dir;
	}

	# http://docs.wxwidgets.org/stable/wx_wxfiledialog.html:
	# "It must be noted that wildcard support in the native Motif file dialog is quite
	# limited: only one alternative is supported, and it is displayed without
	# the descriptive text."
	# But I don't think Wx + Motif is in use nowadays
	my $wildcards = join(
		'|',
		Wx::gettext('JavaScript Files'),
		'*.js;*.JS',
		Wx::gettext('Perl Files'),
		'*.pm;*.PM;*.pl;*.PL',
		Wx::gettext('PHP Files'),
		'*.php;*.php5;*.PHP',
		Wx::gettext('Python Files'),
		'*.py;*.PY',
		Wx::gettext('Ruby Files'),
		'*.rb;*.RB',
		Wx::gettext('SQL Files'),
		'*.sql;*.SQL',
		Wx::gettext('Text Files'),
		'*.txt;*.TXT;*.yml;*.conf;*.ini;*.INI;.*rc',
		Wx::gettext('Web Files'),
		'*.html;*.HTML;*.htm;*.HTM;*.css;*.CSS',
		Wx::gettext('Script Files'),
		'*.sh;*.bat;*.BAT',
	);
	$wildcards =
		Padre::Constant::WIN32
		? Wx::gettext('All Files') . '|*.*|' . $wildcards
		: Wx::gettext('All Files') . '|*|' . $wildcards;
	my $dialog = Wx::FileDialog->new(
		$self, Wx::gettext('Open File'),
		$self->cwd, '', $wildcards, Wx::FD_MULTIPLE,
	);
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	my @filenames = $dialog->GetFilenames;
	$self->{cwd} = $dialog->GetDirectory;

	#print $dialog->GetPath, " <- path\n";
	#print $dialog->GetFilename, " <- filename\n";
	#print $dialog->GetDirectory, " <- directory\n";
	# at least on Linux running Gnome the open file dialog provides a place
	# to paste a full path of a file. If the user does that then the
	# GetFilename method will return this full path while the GetFilename
	# method will return the name of the file only and GetDirectory will point
	# to where the file browser is open which is probably not the same directory
	# in which our file is in
	if ( @filenames == 1 ) {
		my $fullpath = $dialog->GetPath;
		$self->{cwd} = File::Basename::dirname($fullpath);
		@filenames = File::Basename::basename($fullpath);
	}

	my @files;
	foreach my $filename (@filenames) {

		if ( $filename =~ /[\*\?]/ ) {

			# Windows usually handles this at the dialog level, but Gnome doesn't,
			# so this should never appear on Windows:
			my $ret = Wx::MessageBox(
				sprintf(
					Wx::gettext('File name %s contains * or ? which are special chars on most computers. Skip?'),
					$filename
				),
				Wx::gettext("Open Warning"),
				Wx::YES_NO | Wx::CENTRE,
				$self,
			);

			next if $ret == Wx::YES;
		}

		my $FN = File::Spec->catfile( $self->cwd, $filename );

		unless ( -e $FN ) {

			# This could be checked by a Windows dialog, but a Gnome dialog doesn't,
			# and created empty files when you do a typo in the open box when
			# entering and not selecting a filename to open:
			my $ret = Wx::MessageBox(
				sprintf(
					Wx::gettext('File name %s does not exist on disk. Skip?'),
					$FN
				),
				Wx::gettext("Open Warning"),
				Wx::YES_NO | Wx::CENTRE,
				$self,
			);

			next if $ret == Wx::YES;
		}

		push @files, $FN;
	}

	my $lock = $self->lock( 'REFRESH', 'DB' );
	$self->setup_editors(@files) if $#files > -1;
	$self->save_current_session;

	return;
}

=pod

=head3 C<on_open_with_default_system_editor>

    $main->on_open_with_default_system_editor($filename);

Opens C<$filename> in the default system editor

=cut

sub on_open_with_default_system_editor {
	require Padre::Util::FileBrowser;
	Padre::Util::FileBrowser->open_with_default_system_editor($_[1]);
}

=pod

=head3 C<on_open_in_command_line>

    $main->on_open_in_command_line($filename);

Opens a command line/shell using the working directory of C<$filename>

=cut

sub on_open_in_command_line {
	require Padre::Util::FileBrowser;
	Padre::Util::FileBrowser->open_in_command_line($_[1]);
}

=pod

=head3 C<on_open_example>

    $main->on_open_example;

Opens the examples file dialog

=cut

sub on_open_example {
	$_[0]->open_file_dialog( Padre::Util::sharedir('examples') );
}

=pod

=head3 C<on_open_last_closed_file>

    $main->on_open_last_closed_file;

Opens the last closed file in similar fashion to Chrome and Firefox.

=cut

sub on_open_last_closed_file {
	my $self = shift;
	my $last_closed_file = $self->{_last_closed_file} or return;
	$self->setup_editor($last_closed_file);
}

=pod

=head3 C<reload_editor>

    $main->reload_editor;

Try to reload a file from disk. Display an error if something went wrong.

Returns 1 on success and 0 in case of and error.

=cut

sub reload_editor {
	my $self     = shift;
	my $editor   = shift || $self->current->editor or return 0;
	my $document = $editor->document or return 0;
	my $lock     = $editor->lock_update;

	# Capture where we are in the document
	my $line = $editor->LineFromPosition( $editor->GetCurrentPos );

	# Reload the document and propogate to the editor
	unless ( $document->reload ) {
		$self->error(
			sprintf(
				Wx::gettext("Could not reload file: %s"),
				$document->errstr
			)
		);
		return 0;
	}
	$editor->set_document($document);

	# Restore the line position
	my $position = $editor->PositionFromLine($line);
	$editor->SetCurrentPos($position);
	$editor->SetAnchor($position);

	# Refresh the editor title to remove any unsaved marker
	$editor->refresh_notebook;

	return 1;
}

=pod

=head3 C<reload_editors>

    my $success = $main->reload_editors(@editors);

Reloads a series of editors.

Returns true upon success, false otherwise.

=cut

sub reload_editors {
	my $self     = shift;
	my @editors  = @_;

	# Show a progress dialog as this may be long running
	require Padre::Wx::Progress;
	my $progress = Padre::Wx::Progress->new(
		$self,
		Wx::gettext('Reloading Files'),
		$#editors,
		lazy => 1,
	);

	# Interate through the reloads
	my $lock     = $self->lock('REFRESH');
	my $total    = scalar @editors;
	my $notebook = $self->notebook;
	foreach my $i ( 0 .. $#editors ) {
		$progress->update( $i, ($i + 1) . "/$total" );
		$self->reload_editor($editors[$i]) or return 0;
	}

	# Notify the plugin manager of the changed files
	$self->ide->plugin_manager->plugin_event('editor_changed');

	# Refresh everything once we are done
	# TO DO Remove this once reload_editor is smart enough to refresh
	$self->refresh;

	return 1;
}

=pod

=head3 C<reload_all>

    my $success = $main->reload_all;

Reload all open files from disk.

=cut

sub reload_all {
	my $self = shift;
	$self->reload_editors( $self->editors );
}

=pod

=head2 C<reload_dialog>

  $main->reload_dialog;

Displays the "Reload Files" dialog, asking the user which files should
be reloaded and reloading them as specified.

=cut

sub reload_dialog {
	my $self = shift;
	my %args = @_;

	require Padre::Wx::Dialog::WindowList;
	Padre::Wx::Dialog::WindowList->new(
		$self,
		title      => Wx::gettext('Reload Files'),
		list_title => Wx::gettext('&Select files to reload:'),
		buttons    => [
			[
				Wx::gettext('&Reload selected'),
				sub {
					$_[0]->main->reload_editors(@_);
				},
			],
		],
		%args,
	)->show;
}

=pod

=head3 C<on_save>

    my $success = $main->on_save;

Try to save current document. Prompt user for a file name if document was
new (see C<on_save_as()> above). Return true if document has been saved,
false otherwise.

=cut

sub on_save {
	my $self     = shift;
	my $document = shift || $self->current->document;
	return unless $document;

	my $pageid = $self->editor_id( $document->editor );
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

=head3 C<on_save_as>

    my $was_saved = $main->on_save_as;

Prompt user for a new file name to save current document, and save it.
Returns true if saved, false if cancelled.

=cut

sub on_save_as {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $current  = defined( $document->{file} ) ? $document->{file}->filename : undef;

	# Guess the directory to save to
	if ( defined $current ) {
		$self->{cwd} = File::Basename::dirname($current);
	} elsif ( defined $document->project_dir ) {
		$self->{cwd} = $document->project_dir;

		# Support sub-directory intuition
		# if the subdirectory already exists.
		my @subpath = $document->guess_subpath;
		if (@subpath) {
			my $subdir = File::Spec->catdir(
				$document->project_dir,
				@subpath,
			);
			if ( -d $subdir ) {
				$self->{cwd} = $subdir;
			}
		}
	}

	# Guess the filename to save to
	my $filename = $document->guess_filename;
	$filename = '' unless defined $filename;

	while (1) {
		my $dialog = Wx::FileDialog->new(
			$self, Wx::gettext('Save file as...'),
			$self->{cwd},
			$filename,
			Wx::gettext('All Files') . ( Padre::Constant::WIN32 ? '|*.*' : '|*' ),
			Wx::FD_SAVE,
		);
		if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
			return;
		}

		# GetPath will return the typed in string
		# for a file path to be saved to.
		# now we need to work out if we use GetPath
		# or concatinate the two values used.
		$self->{cwd} = $dialog->GetDirectory;
		my $saveto = $dialog->GetPath;
		my $path   = File::Spec->catfile($saveto);
		if ( -e $path ) {
			my $response = Wx::MessageBox(
				Wx::gettext("File already exists. Overwrite it?"),
				Wx::gettext("Exist"), Wx::YES_NO, $self,
			);
			if ( $response == Wx::YES ) {
				$document->set_filename($path);
				$document->save_file;
				$document->set_newline_type(Padre::Constant::NEWLINE);
				last;
			}
		} else {
			$document->set_filename($path);
			$document->save_file;
			$document->set_newline_type(Padre::Constant::NEWLINE);
			delete $document->{project_dir};
			last;
		}
	}
	my $pageid = $self->notebook->GetSelection;
	$self->_save_buffer($pageid);

	$document->set_mimetype( $document->guess_mimetype );
	$document->editor->setup_document;
	$document->rebless;
	$document->colourize;

	if ( defined $document->{file} ) {
		$filename = $document->{file}->filename;
	}
	if ( defined $filename ) {
		Padre::DB::History->create(
			type => 'files',
			name => $filename,
		);

		# Immediately refresh the recent list, or save the request
		# for refresh lock expiry. We probably should add a specific
		# lock method for this non-guard-object case.
		# We also need to refresh the directory list, in case a change
		# in file name means the project context has changed.
		$self->lock( 'refresh_recent', 'refresh_directory' );
	}

	$self->refresh;

	return 1;
}

=pod

=head3 C<on_save_intuition>

    my $success = $main->on_save_intuition;

Try to automatically determine an appropriate file name and save it,
based entirely on the content of the file.

Only do this for new documents, otherwise behave like a regular save.

=cut

sub on_save_intuition {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document or return;

	# We only use Save Intuition for new files
	unless ( $document->is_new ) {
		if ( $document->is_saved ) {

			# Nothing to do
			return;
		} else {

			# Regular save
			return $self->on_save(@_);
		}
	}

	# Empty files get done via the normal save
	if ( $document->is_unused ) {
		return $self->on_save_as(@_);
	}

	# Don't use Save Intuition in null projects
	my $project = $current->project;
	unless ($project) {
		return $self->on_save_as(@_);
	}

	# We need both a guessed path and file name to do anything
	my @subpath  = $document->guess_subpath;
	my $filename = $document->guess_filename;
	unless ( @subpath and defined Params::Util::_STRING($filename) ) {

		# Cannot come up with a suitable guess
		return $self->on_save_as(@_);
	}

	# Convert the guesses to full paths
	my $dir = File::Spec->catdir( $document->project_dir, @subpath );
	my $path = File::Spec->catfile( $dir, $filename );
	if ( -f $path ) {

		# Potential collision, error and fall back
		$self->error( Wx::gettext('File already exists') );
		return $self->on_save_as(@_);
	}

	# Create the directory, if needed
	unless ( -d $dir ) {
		my $error = [];
		File::Path::make_path(
			$dir,
			{   verbose => 0,
				error   => \$error,
			}
		);
		if (@$error) {
			$self->error( sprintf( Wx::gettext("Failed to create path '%s'"), $dir ) );
			return $self->on_save_as(@_);
		}
	}

	# Save the file
	$document->set_filename($path);
	$document->save_file;
	$document->set_newline_type(Padre::Constant::NEWLINE);

	# Laborious copy of the above.
	# Generalise it later
	my $pageid = $self->notebook->GetSelection;
	$self->_save_buffer($pageid);

	$document->set_mimetype( $document->guess_mimetype );
	$document->editor->setup_document;
	$document->rebless;
	$document->colourize;

	$filename = $document->{file}->filename if defined( $document->{file} );
	if ( defined($filename) ) {
		Padre::DB::History->create(
			type => 'files',
			name => $filename,
		);

		# Immediately refresh the recent list, or save the request
		# for refresh lock expiry. We probably should add a specific
		# lock method for this non-guard-object case.
		$self->lock('refresh_recent');
	}

	$self->refresh;

	return 1;
}

=pod

=head3 C<on_save_all>

    my $success = $main->on_save_all;

Try to save all opened documents. Return true if all documents were
saved, false otherwise.

=cut

sub on_save_all {
	my $self     = shift;
	my $notebook = $self->notebook;
	my $selected = $notebook->GetSelection;

	# Are there any modified documents?
	my @modified = $self->documents_modified or return 1;

	# Save the unmodified documents
	foreach my $document ( @modified ) {
		$self->on_save($document) or return 0;
	}

	# If we ended up with a different document in focus,
	# return the focus to the original one.
	unless ( $notebook->GetSelection == $selected ) {
		$notebook->SetSelection($selected);
		$self->editor_focus;
	}

	# Force-refresh backups (i.e. probably delete them)
	$self->backup(1);

	return 1;
}

=pod

=head3 C<_save_buffer>

    my $success = $main->_save_buffer($id);

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
			Wx::YES_NO | Wx::CENTRE,
			$self,
		);
		return if $ret != Wx::YES;
	}

	unless ( $doc->save_file ) {
		$self->error(
			Wx::gettext("Could not save file: ") . $doc->errstr,
			Wx::gettext("Error"),
		);
		return;
	}

	$page->SetSavePoint;
	$self->refresh;

	return 1;
}

=pod

=head3 C<on_close>

    $main->on_close( $event );

Handler when there is a close C<$event>. Veto it if it's from the C<AUI>
notebook, since Wx will try to close the tab no matter what. Otherwise,
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

	# Transaction-wrap the session saving.
	# If we are closing the last document we need to trigger a full
	# refresh. If not, closing this file results in a focus event
	# on the next remaining document, which does the refresh for us.
	my @methods = ('update_last_session');
	push @methods, 'refresh' unless $self->editors;
	my $lock = $self->lock( 'DB', @methods );

	$self->save_current_session;

	return;
}

=pod

=head3 C<close>

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

	my $editor   = $notebook->GetPage($id) or return;
	my $document = $editor->{Document}     or return;
	my $lock     = $self->lock(
		qw{
			REFRESH
			DB
			refresh_directory
			refresh_menu
			refresh_windowlist
			}
	);
	TRACE( join ' ', "Closing ", ref $document, $document->filename || 'Unknown' ) if DEBUG;

	if ( $document->is_modified and not $document->is_unused ) {
		my $ret = Wx::MessageBox(
			Wx::gettext("File changed. Do you want to save it?"),
			$document->filename || Wx::gettext("Unsaved File"),
			Wx::YES_NO | Wx::CANCEL | Wx::CENTRE,
			$self,
		);
		if ( $ret == Wx::YES ) {
			$self->on_save($document);
		} elsif ( $ret == Wx::NO ) {

			# just close it
		} else {

			# Wx::CANCEL, or when clicking on [x]
			return 0;
		}
	}

	# Ticket #828 - ordering is probably important here
	#   when should plugins be notified ?
	$self->ide->plugin_manager->editor_disable($editor);

	# Also, if any padre-client or other listeners to this file exist,
	# notify it that we're done with it:
	my $fn = $document->filename;
	if ($fn) {
		@{ $self->{on_close_watchers}->{$fn} } = map {
			warn "Calling on_close() callback";
			my $remove = $_->($document);
			$remove ? () : $_
		} @{ $self->{on_close_watchers}->{$fn} };
	}

	if (Padre::Feature::CURSORMEMORY) {
		$editor->store_cursor_position;
	}
	if ( $document->tempfile ) {
		$document->remove_tempfile;
	}

	# Now we are past the confirmation, apply an update lock as well
	my $lock2 = $self->lock('UPDATE');

	$self->notebook->DeletePage($id);

	# NOTE: Why are we doing an explicit clear?
	# Wouldn't a refresh to them clear if needed anyway?
	if ( $self->has_syntax ) {
		$self->syntax->clear;
	}
	if ( $self->has_outline ) {
		$self->outline->clear;
	}

	# Release all locks
	undef $lock;

	$self->refresh_recent;

	return 1;
}

=pod

=head3 C<close_all>

    my $success = $main->close_all( $skip );

Try to close all documents. If C<$skip> is specified (an integer), don't
close the tab with this id. Return true upon success, false otherwise.

=cut

sub close_all {
	my $self = shift;
	my $skip = shift;
	my $lock = $self->lock('UPDATE');

	my $manager = $self->{ide}->plugin_manager;

	$self->save_current_session;

	# Remove current session ID from IDE object
	# Do this before closing as the session shouldn't be affected by a close-all
	undef $self->ide->{session};

	my @pages = reverse $self->pageids;

	require Padre::Wx::Progress;
	my $progress = Padre::Wx::Progress->new(
		$self, Wx::gettext('Close all'), $#pages,
		lazy => 1
	);

	SCOPE: {
		my $lock = $self->lock('refresh');
		foreach my $no ( 0 .. $#pages ) {
			$progress->update( $no, ( $no + 1 ) . '/' . scalar(@pages) );
			if ( defined $skip and $skip == $pages[$no] ) {
				next;
			}
			$self->close( $pages[$no] ) or return 0;
		}
	}

	# Recalculate window title
	$self->refresh_title;

	$manager->plugin_event('editor_changed');

	# Refresh recent files list
	$self->refresh_recent;

	# Force-refresh backups (i.e. delete them)
	$self->backup(1);

	return 1;
}

=pod

=head3 C<close_some>

    my $success = $main->close_some(@pages_to_close);

Try to close all documents. Return true upon success, false otherwise.

=cut

sub on_close_some {
	my $self = shift;
	my $lock = $self->lock('UPDATE');

	require Padre::Wx::Dialog::WindowList;
	Padre::Wx::Dialog::WindowList->new(
		$self,
		title      => Wx::gettext('Close some files'),
		list_title => Wx::gettext('Select files to close:'),
		buttons    => [
			[
				'Close selected',
				sub {
					$_[0]->main->close_some(@_);
				},
			],
		],
	)->show;
}

sub close_some {
	my $self        = shift;
	my @close_pages = @_;

	my $notebook = $self->notebook;

	my $manager = $self->{ide}->plugin_manager;

	require Padre::Wx::Progress;
	my $progress = Padre::Wx::Progress->new(
		$self, Wx::gettext('Close some'), $#close_pages,
		lazy => 1
	);

	SCOPE: {
		my $lock = $self->lock('refresh');
		foreach my $close_page_no ( 0 .. $#close_pages ) {
			$progress->update( $close_page_no, ( $close_page_no + 1 ) . '/' . scalar(@close_pages) );

			foreach my $pageid ( $self->pageids ) {
				my $page = $notebook->GetPage($pageid);
				next unless defined($page);
				next unless $page eq $close_pages[$close_page_no];
				$self->close($pageid) or return 0;
			}
		}
	}

	# Recalculate window title
	$self->refresh_title;

	$manager->plugin_event('editor_changed');

	return 1;
}

=pod

=head3 C<close_where>

    # Close all files in current project
    my $project = Padre::Current->document->project_dir;
    my $success = $main->close_where( sub {
        $_[0]->project_dir eq $project
    } );

The C<close_where> method is for closing multiple document windows.
It takes a subroutine as a parameter and calls that subroutine
for each currently open document, passing the document as the first
parameter.

Any documents that return true will be closed.

=cut

sub close_where {
	my $self     = shift;
	my $where    = shift;
	my $notebook = $self->notebook;

	# Generate the list of ids to close before we go to the
	# expensive of taking any locks.
	my @close = grep { $where->( $notebook->GetPage($_)->{Document} ) } reverse $self->pageids;
	if (@close) {
		my $lock = $self->lock( 'UPDATE', 'DB', 'refresh' );
		foreach my $id (@close) {
			$self->close($id) or return 0;
		}
	}
	return 1;
}

=pod

=head3 C<on_delete>

    $main->on_delete;

Close the current tab and remove the associated file from disk.
No return value.

=cut

sub on_delete {
	my $self = shift;

	$self->delete;
}

=pod

=head3 C<delete>

    my $success = $main->delete( $id );

Request to close document in tab C<$id>, or current one if no C<$id>
provided and DELETE THE FILE FROM DISK. Return true if closed, false otherwise.

=cut

sub delete {
	my $self     = shift;
	my $notebook = $self->notebook;
	my $id       = shift;
	unless ( defined $id ) {
		$id = $notebook->GetSelection;
	}
	return if $id == -1;

	my $editor   = $notebook->GetPage($id) or return;
	my $document = $editor->{Document}     or return;

	# We need those even when the document is already closed:
	my $file = $document->file;
	my $filename = $document->filename or return;

	if ( !$file->can_delete ) {
		$self->error( Wx::gettext('This type of file (URL) is missing delete support.') );
		return 1;
	}

	if ( !$filename ) {
		$self->error( Wx::gettext("File was never saved and has no filename - can't delete from disk") );
		return 1;
	}

	my $ret = Wx::MessageBox(
		sprintf(
			Wx::gettext("Do you really want to close and delete %s from disk?"),
			$filename
		),
		Wx::YES_NO | Wx::CANCEL | Wx::CENTRE,
		$self,
	);
	return 1 unless $ret == Wx::YES;

	TRACE( join ' ', "Deleting ", ref $document, $filename || 'Unknown' ) if DEBUG;

	$self->close($id);

	my $manager = $self->{ide}->plugin_manager;
	return unless $manager->hook( 'before_delete', $file );

	if ( !$file->delete ) {
		$self->error( sprintf( Wx::gettext("Error deleting %s:\n%s"), $filename, $file->error ) );
		return 1;
	}

	$manager->hook( 'after_delete', $file );

	return 1;
}

=pod

=head3 C<on_nth_path>

    $main->on_nth_pane( $id );

Put focus on tab C<$id> in the notebook. Return true upon success, false
otherwise.

=cut

sub on_nth_pane {
	my $self = shift;
	my $id   = shift;
	my $page = $self->notebook->GetPage($id);
	unless ($page) {
		$self->current->editor->SetFocus;
		return;
	}

	$self->notebook->SetSelection($id);
	$self->refresh_status;
	$page->SetFocus;
	$self->ide->plugin_manager->plugin_event('editor_changed');

	return 1;
}

=pod

=head3 C<on_next_pane>

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

	$self->current->editor->SetFocus;

	return;
}

=pod

=head3 C<on_prev_pane>

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

	$self->current->editor->SetFocus;

	return;
}

=pod

=head3 C<on_join_lines>

    $main->on_join_lines;

Join current line with next one (à la B<vi> with C<Ctrl+J>). No return value.

=cut

sub on_join_lines {
	my $self = shift;
	my $page = $self->current->editor;

	# Don't crash if no document is open
	return if !defined($page);

	# find positions
	my $pos1 = $page->GetCurrentPos;
	my $line = $page->LineFromPosition($pos1);

	# Don't crash if cursor at the last line
	return if ( $line >= 0 ) and ( $line + 1 == $page->GetLineCount );

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

=head3 C<zoom>

    $main->zoom( $factor );

Apply zoom C<$factor> to Padre's documents. Factor can be either
positive or negative.

=cut

sub zoom {
	my $self = shift;
	my $page = $self->current->editor or return;
	my $zoom = $page->GetZoom + shift;

	foreach my $page ( $self->editors ) {
		$page->SetZoom($zoom);
	}

	return 1;
}


=pod

=head3 C<show_regex_editor>

    $main->show_regex_editor;

Open Padre's regular expression editor. No return value.

=cut

sub show_regex_editor {
	my $self = shift;

	unless ( defined $self->{regex_editor} ) {
		require Padre::Wx::Dialog::RegexEditor;
		$self->{regex_editor} = Padre::Wx::Dialog::RegexEditor->new($self);
	}

	unless ( defined $self->{regex_editor} ) {
		$self->error( Wx::gettext('Error loading regex editor.') );
		return;
	}

	$self->{regex_editor}->show;

	return;
}


=pod

=head3 C<show_perl_filter>

    $main->show_perl_filter;

Open Padre's filter-through-perl. No return value.

=cut

sub show_perl_filter {
	my $self = shift;

	unless ( defined $self->{perl_filter} ) {
		require Padre::Wx::Dialog::PerlFilter;
		$self->{perl_filter} = Padre::Wx::Dialog::PerlFilter->new($self);
	}

	unless ( defined $self->{perl_filter} ) {
		$self->error( Wx::gettext('Error loading perl filter dialog.') );
		return;
	}

	$self->{perl_filter}->show;

	return;
}

=pod

=head3 C<editor_linenumbers>

    $main->editor_linenumbers(1);

Set visibility of line numbers on the left of the document.

No return value.

=cut

sub editor_linenumbers {
	my $self = shift;
	my $show = $_[0] ? 1 : 0;
	my $lock = $self->lock('CONFIG');
	$self->config->set( editor_linenumbers => $show );

	foreach my $editor ( $self->editors ) {
		$editor->show_line_numbers($show);
	}

	$self->menu->view->refresh;

	return;
}

=pod

=head3 C<editor_folding>

    $main->editor_folding(1);

Enabled or disables code folding.

No return value.

=cut

BEGIN {
	no warnings 'once';
	*editor_folding = sub {
		my $self = shift;
		my $show = $_[0] ? 1 : 0;
		my $lock = $self->lock('CONFIG');
		my $pod  = $self->config->editor_fold_pod;
		$self->config->set( editor_folding => $show );

		foreach my $editor ( $self->editors ) {
			$editor->show_folding($show);
			if ( $show and $pod ) {
				$editor->fold_pod;
			}
		}

		$self->menu->view->refresh;

		return;
		}
		if Padre::Feature::FOLDING;
}

=pod

=head3 C<editor_currentline>

    $main->editor_currentline(1);

Enable or disable background highlighting of the current line.

No return value.

=cut

sub editor_currentline {
	my $self = shift;
	my $show = $_[0] ? 1 : 0;
	my $lock = $self->lock('CONFIG');
	$self->config->set( editor_currentline => $show );

	foreach my $editor ( $self->editors ) {
		$editor->SetCaretLineVisible($show);
	}

	$self->menu->view->refresh;

	return;
}

sub editor_currentline_color {
	my $self  = shift;
	my $name  = shift;
	my $lock  = $self->lock('CONFIG');
	$self->config->set( editor_currentline_color => $name );

	# Apply the color to all editors
	my $color = Padre::Wx::color($name);
	foreach my $editor ( $self->editors ) {
		$editor->SetCaretLineBackground($color);
	}

	return;
}

=head3 C<editor_rightmargin>

    $main->editor_rightmargin(1);

Enable or disable display of the right margin.

No return value.

=cut

sub editor_rightmargin {
	my $self = shift;
	my $show = $_[0] ? 1 : 0;
	my $lock = $self->lock('CONFIG');
	$self->config->set( editor_right_margin_enable => $show );

	my $column = $self->config->editor_right_margin_column;
	my $mode =
		$show
		? Wx::Scintilla::Constant::EDGE_LINE
		: Wx::Scintilla::Constant::EDGE_NONE;

	foreach my $editor ( $self->editors ) {
		$editor->SetEdgeColumn($column);
		$editor->SetEdgeMode($mode);
	}

	$self->menu->view->refresh;

	return;
}

=pod

=head3 C<editor_indentationguides>

    $main->editor_indentationguides(1);

Enable or disable visibility of the indentation guides.

No return value.

=cut

sub editor_indentationguides {
	my $self = shift;
	my $show = $_[0] ? 1 : 0;
	my $lock = $self->lock('CONFIG');
	$self->config->set( editor_indentationguides => $show );

	foreach my $editor ( $self->editors ) {
		$editor->SetIndentationGuides($show);
	}

	$self->menu->view->refresh;

	return;
}

=pod

=head3 C<editor_eol>

    $main->editor_eol(1);

Show or hide end of line carriage return characters.

No return value.

=cut

sub editor_eol {
	my $self = shift;
	my $show = $_[0] ? 1 : 0;
	my $lock = $self->lock('CONFIG');
	$self->config->set( editor_eol => $show );

	foreach my $editor ( $self->editors ) {
		$editor->SetViewEOL($show);
	}

	$self->menu->view->refresh;

	return;
}

=pod

=head3 C<editor_whitespace>

    $main->editor_whitespace;

Show/hide spaces and tabs (with dots and arrows respectively). No
return value.

=cut

sub editor_whitespace {
	my $self = shift;
	my $show = $_[0] ? 1 : 0;
	my $lock = $self->lock('CONFIG');
	$self->config->set( editor_whitespace => $show );

	my $mode =
		$show
		? Wx::Scintilla::Constant::SCWS_VISIBLEALWAYS
		: Wx::Scintilla::Constant::SCWS_INVISIBLE;

	foreach my $editor ( $self->editors ) {
		$editor->SetViewWhiteSpace($show);
	}

	$self->menu->view->refresh;

	return;
}

=pod

=head2 C<editor_focus>

    $main->editor_focus;

Return focus to the current editor, if one exists. This method is provided
as a convenience for dialog writers who wish to return focus.

=cut

sub editor_focus {
	my $self   = shift;
	my $editor = $self->current->editor;
	$editor->SetFocus if $editor;
	return;
}

=pod

=head3 C<on_word_wrap>

    $main->on_word_wrap;

Toggle word wrapping for current document. No return value.

=cut

sub on_word_wrap {
	my $self = shift;
	my $show = @_ ? $_[0] ? 1 : 0 : 1;
	unless ( $show == $self->menu->view->{word_wrap}->IsChecked ) {
		$self->menu->view->{word_wrap}->Check($show);
	}

	my $doc = $self->current->document or return;
	my $mode =
		$show
		? Wx::Scintilla::Constant::SC_WRAP_WORD
		: Wx::Scintilla::Constant::SC_WRAP_NONE;

	$doc->editor->SetWrapMode($mode);
}

=pod

=head3 C<show_toolbar>

    $main->show_toolbar;

Toggle toolbar visibility. No return value.

=cut

sub show_toolbar {
	my $self = shift;
	my $show = $_[0] ? 1 : 0;
	my $lock = $self->lock('CONFIG');
	$self->config->set( main_toolbar => $show );

	if ($show) {

		# Add the toolbar
		$self->rebuild_toolbar;
	} else {

		# Remove the toolbar
		my $toolbar = $self->GetToolBar;
		if ($toolbar) {
			$toolbar->Destroy;
			$self->SetToolBar(undef);
		}
	}

	# Explicit refresh of the AUI manager.
	$self->aui->Update;

	$self->menu->view->refresh;

	return;
}

=pod

=head3 C<show_statusbar>

    $main->show_statusbar;

Toggle status bar visibility. No return value.

=cut

sub show_statusbar {
	my $self = shift;
	my $show = $_[0] ? 1 : 0;
	my $lock = $self->lock('CONFIG');
	$self->config->set( main_statusbar => $show );

	# Update the status bar
	if ($show) {
		$self->GetStatusBar->Show;
	} else {
		$self->GetStatusBar->Hide;
	}

	# Explicit refresh of the AUI manager.
	$self->aui->Update;

	$self->menu->view->refresh;

	return;
}

=pod

=head3 C<on_toggle_lockinterface>

    $main->on_toggle_lockinterface;

Toggle possibility for user to change Padre's external aspect. No
return value.

=cut

sub on_toggle_lockinterface {
	my $self = shift;
	my $lock = $self->lock('CONFIG');

	# Update setting
	$self->config->apply(
		'main_lockinterface',
		$self->menu->view->{lockinterface}->IsChecked ? 1 : 0,
	);

	return;
}

=pod

=head3 C<on_insert_from_file>

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
		$self,      Wx::gettext('Open file'),
		$self->cwd, '',
		Wx::gettext('All Files') . ( Padre::Constant::WIN32 ? '|*.*' : '|*' ),
		Wx::FD_OPEN,
	);
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	my $filename = $dialog->GetFilename;
	$self->{cwd} = $dialog->GetDirectory;

	my $file = File::Spec->catfile( $self->cwd, $filename );
	$editor->insert_from_file($file);

	return;
}

=pod

=head3 C<convert_to>

    $main->convert_to( $eol_style );

Convert document to C<$eol_style> line endings (can be one of C<WIN>,
C<UNIX>, or C<MAC>). No return value.

=cut

sub convert_to {
	my $self    = shift;
	my $newline = shift;
	$self->current->editor->convert_eols($newline);
	$self->refresh;
}

=pod

=head3 C<editor_of_file>

    my $editor = $main->editor_of_file( $file );

Return the editor (a C<Padre::Wx::Editor> object) containing the wanted
C<$file>, or C<undef> if file is not opened currently.

=cut

sub editor_of_file {
	require Padre::File;
	my $self     = shift;
	my $file     = Padre::File->new(shift); # This reformats our filename
	my $notebook = $self->notebook;
	foreach my $id ( $self->pageids ) {
		my $editor   = $notebook->GetPage($id) or return;
		my $document = $editor->{Document}     or return;
		defined( $document->{file} ) or next;
		my $doc_filename = $document->{file}->{filename} or next;
		return $id if $doc_filename eq $file->{filename};
	}
	return;
}

=pod

=head3 C<editor_id>

    my $id = $main->editor_id( $editor );

Given C<$editor>, return the tab id holding it, or C<undef> if it was
not found.

Note: can this really work? What happens when we split a window?

=cut

sub editor_id {
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

=head3 C<run_in_padre>

    $main->run_in_padre;

Evaluate current document within Padre. It means it can access all of
Padre's internals, and wreak havoc. Display an error message if the evaluation
went wrong, dump the result in the output panel otherwise.

No return value.

=cut

sub run_in_padre {
	my $self = shift;
	my $doc  = $self->current->document or return;
	my $code = $doc->text_get;
	my @rv   = eval $code;
	if ($@) {
		$self->error(
			sprintf( Wx::gettext("Error: %s"), $@ ),
			Wx::gettext("Internal error"),
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

=head2 C<STC> related methods

Those methods are needed to have a smooth C<STC> experience.

=head3 C<on_stc_style_needed>

    $main->on_stc_style_needed( $event );

Handler of C<EVT_STC_STYLENEEDED> C<$event>. Used to work around some edge
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

=head3 C<on_stc_update_ui>

    $main->on_stc_update_ui;

Handler called on every movement of the cursor. No return value.

=cut

# NOTE: Any blocking here is HIGHLY visible to the user
# so you should be extremely cautious in here. Everything
# in this sub should be super super fast.
sub on_stc_update_ui {
	my $self = shift;

	# Avoid recursion
	return if $self->{_in_stc_update_ui};
	local $self->{_in_stc_update_ui} = 1;

	# Check for brace, on current position, highlight the matching brace
	my $current = $self->current;
	my $editor  = $current->editor;
	return if not defined $editor;
	$editor->highlight_braces;
	$editor->show_calltip;

	# Avoid refreshing the subs as that takes a lot of time
	# TO DO maybe we should refresh it on every 20s hit or so
	$editor->refresh_notebook;
	$self->refresh_toolbar($current);

	# $self->refresh_status($current);
	$self->refresh_status_template($current);
	$self->refresh_cursorpos($current);

	# This call makes live filesystem calls every time the cursor moves
	# Clearly this is incredibly evil, commenting out till whoever wrote
	# this works out what they meant to do and does it better.
	# $self->refresh_rdstatus($current);

	return;
}

=pod

=head3 C<on_stc_change>

    $main->on_stc_change;

Handler of the C<EVT_STC_CHANGE> event. Doesn't do anything. No
return value.

=cut

sub on_stc_change {
	return;
}

=pod

=head3 C<on_stc_char_needed>

    $main->on_stc_char_added;

This handler is called when a character is added. No return value. See
L<http://www.scintilla.org/ScintillaDoc.html#SCN_CHARADDED>

TO DO: maybe we need to check this more carefully.

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

=head3 C<on_aui_pane_close>

    $main->on_aui_pane_close( $event );

Handler called upon C<EVT_AUI_PANE_CLOSE> C<$event>. Doesn't do anything by now.

=cut

sub on_aui_pane_close {
	$_[0]->GetPane;
}

=pod

=head3 C<on_tab_and_space>

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

	require Padre::Wx::TextEntryDialog::History;
	my $dialog = Padre::Wx::TextEntryDialog::History->new(
		$self,
		Wx::gettext('How many spaces for each tab:'),
		$title, $type,
	);
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
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

=head3 C<on_delete_trailing_spaces>

    $main->on_delete_trailing_spaces;

Trim all ending spaces in current selection, or document if no text is
selected. No return value.

=cut

sub on_delete_trailing_spaces {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document or return;
	my $selected = $current->text;
	unless ( length $selected ) {
		return $document->delete_trailing_spaces;
	}

	# Remove trailing space from selected text
	$selected =~ s/([^\n\S]+)$//mg;

	# Replace only if the selection is changed
	unless ( $selected eq $current->text ) {
		$current->editor->ReplaceSelection($selected);
	}

	return;
}

=pod

=head3 C<on_delete_leading_spaces>

    $main->on_delete_leading_spaces;

Trim all leading spaces in current selection. No return value.

=cut

sub on_delete_leading_spaces {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document or return;
	my $selected = $current->text;
	unless ( length $selected ) {
		return $document->delete_leading_spaces;
	}

	# Remove trailing space from selected text
	$selected =~ s/^[ \t]+//mg;

	# Replace only if the selection is changed
	unless ( $selected eq $current->text ) {
		$current->editor->ReplaceSelection($selected);
	}

	return;
}

=pod

=head3 C<timer_check_overwrite>

    $main->timer_check_overwrite;

Called every n seconds to check if file has been overwritten outside of
Padre. If that's the case, prompts the user whether s/he wants to reload
the document. No return value.

=cut

sub timer_check_overwrite {
	my $self  = shift;
	my $doc   = $self->current->document or return;
	my $state = $doc->has_changed_on_disk; # 1 = updated, 0 = unchanged, -1 = deleted

	return unless $state;
	return if $doc->{_already_popup_file_changed};

	$doc->{_already_popup_file_changed} = 1;
	$self->reload_dialog( no_fresh => 1 );

	return;
}

=pod

=head3 C<on_duplicate>

    $main->on_duplicate;

Create a new document and copy the contents of the current file.
No return value.

=cut

sub on_duplicate {
	my $self = shift;
	my $document = $self->current->document or return;
	return $self->new_document_from_string(
		$document->text_get,
		$document->mimetype,
	);
}

=pod

=head2 Code Starter Methods

These methods provide skeleton generators for a variety of file types, with
the preferences of the user applied already.

=head3 C<start_perl6_script>

    $main->start_perl6_script;

Create a new blank Perl 6 script, applying the user's style preferences if
possible.

=cut

# For now, we don't actually apply their style preferences
sub start_perl6_script {
	my $self = shift;

	# Generate the code from the script template
	require Padre::Template;
	my $code = Padre::Template->render('perl6/script_p6.tt');

	# Show the new file in a new editor window
	$self->new_document_from_string( $code, 'application/x-perl6' );
}

=pod

=head2 Auxiliary Methods

Various methods that did not fit exactly in above categories...

=head3 C<action>

  Padre::Current->main->action('help.about');

Single execution of a named action.

=cut

sub action {
	my $self = shift;
	my $name = shift;

	# Does the action exist
	my $action = $self->ide->{actions}->{$name};
	die "No such action '$name'" unless $action;

	# Execute the action
	$action->menu_event->($self);
	return 1;
}

=pod

=head3 C<setup_bindings>

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

	# Update the colourise for each editor of the relevant mime-type
	# Trying to delay the actual color updating for the
	# pages that are not in focus till they get in focus
	my $focused = $self->current->editor;
	foreach my $editor ( $self->editors ) {
		my $document = $editor->{Document};
		next if $document->mimetype ne $mime_type;
		$document->set_highlighter($module);
		my $filename = defined( $document->{file} ) ? $document->{file}->filename : undef;
		TRACE( "Set highlighter to to $module for $document in file " . ( $filename || '' ) ) if DEBUG;
		$editor->SetLexer( $document->mimetype );

		TRACE("Editor $editor focused $focused") if DEBUG;
		if ( $editor eq $focused ) {
			$editor->needs_manual_colorize(0);
			$document->colourize;
		} else {
			$editor->needs_manual_colorize(1);
		}
	}

	return;
}

=pod

=head3 C<key_up>

    $main->key_up( $event );

Callback for when a key up C<$event> happens in Padre. This handles the
various C<Ctrl>+key combinations used within Padre.

=cut

sub key_up {
	my $self   = shift;
	my $event  = shift;
	my $mod    = $event->GetModifiers || 0;
	my $code   = $event->GetKeyCode;
	my $config = $self->config;

	# Remove the bit ( Wx::MOD_META) set by Num Lock being pressed on Linux
	# () needed after the constants as they are functions in Perl and
	# without constants perl will call only the first one.
	$mod = $mod & ( Wx::MOD_ALT + Wx::MOD_CMD + Wx::MOD_SHIFT );
	if ( $mod == Wx::MOD_CMD ) { # Ctrl
		                         # Ctrl-TAB TO DO it is already in the menu
		if ( $code == Wx::K_TAB ) {
			&{ $self->ide->actions->{'window.next_file'}->menu_event }( $self, $event );
		}
	} elsif ( $mod == Wx::MOD_CMD + Wx::MOD_SHIFT ) { # Ctrl-Shift
		                                              # Ctrl-Shift-TAB
		                                              # TODO it is already in the menu
		if ( $code == Wx::K_TAB ) {

			&{ $self->ide->actions->{'window.previous_file'}->menu_event }( $self, $event );
		}
	} elsif ( $mod == Wx::MOD_ALT ) {

		#		my $current_focus = Wx::Window::FindFocus();
		#		TRACE("Current focus: $current_focus") if DEBUG;
		#		# TO DO this should be fine tuned later
		#		if ($code == Wx::K_UP) {
		#			# TO DO get the list of panels at the bottom from some other place
		#			if (my $editor = $self->current->editor) {
		#				if ($current_focus->isa('Padre::Wx::Output') or
		#					$current_focus->isa('Padre::Wx::Syntax')
		#				) {
		#					$editor->SetFocus;
		#				}
		#			}
		#		} elsif ($code == Wx::K_DOWN) {
		#			#TRACE("Selection: " . $self->bottom->GetSelection) if DEBUG;
		#			#$self->bottom->GetSelection;
		#		}
	} elsif ( !$mod and $code == 27 ) { # ESC
		&{ $self->ide->actions->{'view.close_panel'}->menu_event }( $self, $event );
	}

	if ( $config->autocomplete_always and ( !$mod ) and ( $code == 8 ) ) {
		$self->on_autocompletion($event);
	}

	# Backup unsaved files if needed
	# NOTE: This should be moved to occur only on the dwell (i.e. at the
	# same time an undo block is saved) and probably shouldn't HAVE to
	# rewrite all files when one is changed.
	$self->backup;

	$event->Skip(1);

	return;
}

# TO DO enable/disable menu options
sub show_as_numbers {
	my $self    = shift;
	my $event   = shift;
	my $form    = shift;
	my $current = $self->current;
	return unless $current->editor;

	my $text = $current->text;
	unless ($text) {
		$self->message( Wx::gettext('Need to select text in order to translate numbers') );
		return;
	}

	$self->show_output(1);
	my $output = $self->output;
	$output->Remove( 0, $output->GetLastPosition );

	# TO DO deal with wide characters ?
	# TO DO split lines, show location ?
	foreach my $i ( 0 .. length($text) ) {
		my $decimal = ord( substr( $text, $i, 1 ) );
		$output->AppendText(
			(     $form eq 'decimal'
				? $decimal
				: uc( sprintf( '%0.2x', $decimal ) )
			)
			. ' '
		);
	}

	return;
}

# showing the Browser window
sub help {
	my $self  = shift;
	my $param = shift;

	unless ( $self->{help} ) {
		require Padre::Wx::Browser;
		$self->{help} = Padre::Wx::Browser->new;
		Wx::Event::EVT_CLOSE(
			$self->{help},
			sub {
				if ( $_[1]->CanVeto ) {
					$_[0]->Hide;
				} else {
					$_[0]->Destroy;

					# The first element is the Padre::Wx::Browser object in this call
					#delete $_[0]->{help};
				}
			},
		);
	}

	$self->{help}->SetFocus;
	$self->{help}->Show(1);
	$self->{help}->help($param) if $param;

	return;
}

sub set_mimetype {
	my $self      = shift;
	my $mime_type = shift;

	my $doc = $self->current->document;
	if ($doc) {
		$doc->set_mimetype($mime_type);
		$doc->editor->setup_document;
		$doc->rebless;
		$doc->colourize;
	}
	$self->refresh;
}

=pod

=head3 C<new_document_from_string>

    $main->new_document_from_string( $string, $mimetype, $encoding );

Create a new document in Padre with the string value.

Pass in an optional mime type to have Padre colorize the text correctly.

Pass in an optional encoding name that will be used when saving the file.

Note: this method may not belong here...

=cut

sub new_document_from_string {
	my $self     = shift;
	my $string   = shift;
	my $mimetype = shift;
	my $encoding = shift;

	# If we are currently focused on an unused document,
	# reuse that instead of making a new one.
	my $document = $self->current->document;
	unless ( $document and $document->is_unused ) {
		$self->on_new;
	}
	$document = $self->current->document or return;

	# Fill the document
	$document->text_set($string);
	$document->set_mimetype($mimetype) if $mimetype;
	$document->set_encoding($encoding) if $encoding;
	$document->{original_content} = $document->text_get;
	$document->editor->setup_document;
	$document->rebless;
	$document->colourize;

	return $document;
}

sub filter_tool {
	my $self    = shift;
	my $cmd     = shift;
	my $current = $self->current;

	return 0 unless defined $cmd;
	return 0 if $cmd eq '';

	my $text = $current->text;
	if ( defined $text and $text ne '' ) {

		# Process a selection
		my $newtext = $self->_filter_tool_run( $cmd, \$text );
		if ( defined $newtext and $newtext ne '' ) {
			$current->editor->ReplaceSelection($newtext);
		}

	} else {

		# No selection, process whole document
		my $document = $current->document;
		my $text     = $document->text_get;
		my $newtext  = $self->_filter_tool_run( $cmd, \$text );
		if ( defined $newtext and $newtext ne '' ) {
			$document->text_replace($newtext);
		}
	}

	return 1;
}

sub _filter_tool_run {
	my $self = shift;
	my $cmd  = shift;
	my $text = shift; # reference to avoid copying the content again

	my $filter_in;
	my $filter_out;
	my $filter_err;

	require IPC::Open3;
	unless ( IPC::Open3::open3( $filter_in, $filter_out, $filter_err, $cmd ) ) {
		$self->error(
			sprintf(
				Wx::gettext("Error running filter tool:\n%s"),
				$!,
			)
		);
		return;
	}

	print $filter_in ${$text};
	CORE::close $filter_in; # Send EOF to tool
	my $newtext = join '', <$filter_out>;

	if ( defined $filter_err ) {

		# The error channel may not exist
		my $errtext = join '', <$filter_err>;
		if ( defined $errtext and $errtext ne '' ) {
			$self->error(
				sprintf(
					Wx::gettext("Error returned by filter tool:\n%s"),
					$errtext,
				)
			);

			# We may also have a result, so don't return here
		}
	}

	return $newtext;
}

# Encode the current document to some character set
sub encode {
	my $self     = shift;
	my $charset  = shift;
	my $document = $self->current->document;

	$document->{encoding} = $charset;
	if ( $document->filename ) {
		$document->save_file;
	}
	$self->message(
		sprintf(
			Wx::gettext('Document encoded to (%s)'),
			$charset,
		)
	);
	return;
}

sub encode_utf8 {
	$_[0]->encode('utf-8');
}

sub encode_default {
	$_[0]->encode( Padre::Locale::encoding_system_default() || 'utf-8' );
}

sub encode_dialog {
	my $self = shift;

	# Select an encoding
	require Encode;
	my $charset = $self->single_choice(
		Wx::gettext('Encode to:'),
		Wx::gettext("Encode document to..."),
		[ Encode->encodings(":all") ],
	);

	# Change to the selected encoding
	if ( defined $charset ) {
		$self->encode($charset);
	}

	return;
}





######################################################################
# Document Backup

sub backup {
	my $self     = shift;
	my $force    = shift;
	my $duration = time - $self->{backup};
	if ( $duration < BACKUP_INTERVAL and not $force ) {
		return;
	}

	# Load and fire the backup task
	require Padre::Task::BackupUnsaved;
	Padre::Task::BackupUnsaved->new->schedule;
	$self->{backup} = time;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
