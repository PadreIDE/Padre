package Padre::Wx::Main;

#
# WARNING: This is a sample file for testing the TODO list, don't use it as Padre source!
# 
# Usage: Open this file, enable the TODO list from the view menu and you should get 3
#        lines in the list. Double click each of them to go to each item.

use utf8; # TODO: First todo test

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
use FindBin;
use Cwd                       ();
use Padre::Wx                 ();

our $VERSION    = '0.00';
our $COMPATIBLE = '0.00';
our @ISA        = qw{
	Padre::Wx
};

use constant SECONDS => 1000;

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

	# Bootstrap some Wx internals
	# TODO second test case
	Wx::Log::SetActiveTarget( Wx::LogStderr->new );
	Wx::InitAllImageHandlers();

	# Initialise the style and position
	my $config   = $ide->config;
	my $size     = [ $config->main_width, $config->main_height ];
	my $position = [ $config->main_left, $config->main_top ];
	my $style    = Wx::wxDEFAULT_FRAME_STYLE;

	# If we closed while maximized on the previous run,
	# the previous size is completely suspect.
	# This doesn't work on Windows,
	# so we use a different mechanism for it.
	if ( not Padre::Constant::WIN32 and $config->main_maximized ) {
		$style |= Wx::wxMAXIMIZE;
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

	# Remember where the editor started from,
	# this could be handy later.
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
		chdir( File::HomeDir->my_home );
	}

	# Create the lock manager before any gui operations,
	# so that we can do locking operations during startup.
	$self->{locker} = Padre::Locker->new($self);

	# Bootstrap locale support before we start fiddling with the GUI.
	my $startup_locale = $ide->opts->{startup_locale};
	$self->{locale} = ( $startup_locale ? Padre::Locale::object($startup_locale) : Padre::Locale::object() );

	# A large complex application looks, frankly, utterly stupid
	# if it gets very small, or even mildly small.
	$self->SetMinSize( Wx::Size->new( 500, 400 ) );

	# Bootstrap drag and drop support
	Padre::Wx::FileDropTarget->set($self);

	# Bootstrap the action system
	Padre::Wx::ActionLibrary->init($self);

	# Bootstrap the wizard system
	Padre::Wx::WizardLibrary->init($self);

	# Temporary store for the notebook tab history
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

	# Use Padre's icon
	if (Padre::Constant::WIN32) {

		# Windows needs its ICO'n file for Padre to look cooler in
		# the task bar, task switch bar and task manager
		$self->SetIcons(Padre::Wx::Icon::PADRE_ICON_FILE);
	} else {
		$self->SetIcon(Padre::Wx::Icon::PADRE);
	}

	# Show the tools that the configuration dictates.
	# Use the fast and crude internal versions here only,
	# so we don't accidentally trigger any configuration writes.
	$self->show_view( todo      => $config->main_todo      );
	$self->show_view( syntax    => $config->main_syntax    );
	$self->show_view( output    => $config->main_output    );
	$self->show_view( outline   => $config->main_outline   );
	$self->show_view( command   => $config->main_command   );
	$self->show_view( functions => $config->main_functions );
	$self->show_view( directory => $config->main_directory );

	# Lock the panels if needed
	$self->aui->lock_panels( $config->main_lockinterface );

	# This require is only here so it can follow this constructor
	# when it moves to being created on demand.
	require Padre::Wx::Debugger;
	$self->{debugger} = Padre::Wx::Debugger->new;

	# We need an event immediately after the window opened
	# (we had an issue that if the default of main_statusbar was false it did
	# not show the status bar which is ok, but then when we selected the menu
	# to show it, it showed at the top) so now we always turn the status bar on
	# at the beginning and hide it in the timer, if it was not needed
	#$statusbar->Show;
	my $timer = Wx::Timer->new(
		$self,
		Padre::Wx::Main::TIMER_POSTINIT,
	);
	Wx::Event::EVT_TIMER(
		$self,
		Padre::Wx::Main::TIMER_POSTINIT,
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

=pod

=head3 C<on_open_in_file_browser>

    $main->on_open_in_file_browser( $filename );

Opens the current C<$filename> using the operating system's file browser

TODO: Test line in pod

=cut

sub on_open_in_file_browser {
	my ( $self, $filename ) = @_;

	require Padre::Util::FileBrowser; #TO-DO test line 3
	Padre::Util::FileBrowser->open_in_file_browser($filename);
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
