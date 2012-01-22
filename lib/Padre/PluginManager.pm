package Padre::PluginManager;

=pod

=head1 NAME

Padre::PluginManager - Padre plug-in manager

=head1 DESCRIPTION

The C<PluginManager> class contains logic for locating and loading Padre
plug-ins, as well as providing part of the interface to plug-in writers.

=head1 METHODS

=cut

# API NOTES:
# - This class uses english-style verb_noun method naming

use 5.008;
use strict;
use warnings;
use Carp                   ();
use File::Path             ();
use File::Spec             ();
use File::Basename         ();
use Scalar::Util           ();
use Params::Util           ();
use Class::Inspector       ();
use Padre::Constant        ();
use Padre::Current         ();
use Padre::Util            ();
use Padre::PluginHandle    ();
use Padre::DB              ();
use Padre::Wx              ();
use Padre::Wx::Menu::Tools ();
use Padre::Locale::T;

our $VERSION = '0.94';





#####################################################################
# Contants and definitions

# Constants limited to this file
use constant PADRE_HOOK_RETURN_IGNORE => 1;
use constant PADRE_HOOK_RETURN_ERROR  => 2;

#  List if valid Padre hooks:
our %PADRE_HOOKS = (
	before_delete => PADRE_HOOK_RETURN_ERROR,
	after_delete  => PADRE_HOOK_RETURN_IGNORE,
	before_save   => PADRE_HOOK_RETURN_ERROR,
	after_save    => PADRE_HOOK_RETURN_IGNORE,
);





#####################################################################
# Constructor and Accessors

=pod

=head2 C<new>

The constructor returns a new C<Padre::PluginManager> object, but
you should normally access it via the main Padre object:

  my $manager = Padre->ide->plugin_manager;

First argument should be a Padre object.

=cut

sub new {
	my $class  = shift;
	my $parent = Params::Util::_INSTANCE( shift, 'Padre' )
		or Carp::croak("Creation of a Padre::PluginManager without a Padre not possible");

	my $self = bless {
		parent       => $parent,
		plugins      => {},
		plugin_dir   => Padre::Constant::PLUGIN_DIR,
		plugin_order => [],
		@_,
	}, $class;

	# Initialize empty My Plugin if needed
	$self->reset_my_plugin(0);

	return $self;
}

=pod

=head2 C<parent>

Stores a reference back to the parent IDE object.

=head2 C<plugin_dir>

Returns the user plug-in directory (below the Padre configuration directory).
This directory was added to the C<@INC> module search path.

=head2 C<plugins>

Returns a hash (reference) of plug-in names associated with a
L<Padre::PluginHandle>.

This hash is only populated after C<load_plugins()> was called.

=cut

use Class::XSAccessor {
	getters => {
		parent     => 'parent',
		plugin_dir => 'plugin_dir',
		plugins    => 'plugins',
	},
};

=head2 current

Gets a L<Padre::Current> context for the plugin manager.

=cut

sub current {
	Padre::Current->new( ide => $_[0]->{parent} );
}

=head2 C<main>

A convenience method to get to the main window.

=cut

sub main {
	$_[0]->parent->wx->main;
}

# Get the preferred plugin order.
# The order calculation cost is higher than we might like,
# so cache the result.
sub plugin_order {
	my $self = shift;
	unless ( $self->{plugin_order} ) {

		# Schwartzian transform that sorts the plugins by their
		# full names, but always puts "My Plug-in" first.
		$self->{plugin_order} = [
			map { $_->[0] } sort {
				( $b->[0] eq 'Padre::Plugin::My' ) <=> ( $a->[0] eq 'Padre::Plugin::My' )
					or $a->[1] cmp $b->[1]
				} map {
				[ $_->class, $_->plugin_name ]
				} values %{ $self->{plugins} }
		];
	}
	return @{ $self->{plugin_order} };
}

sub handles {
	map { $_[0]->{plugins}->{$_} } $_[0]->plugin_order;
}





#####################################################################
# Bulk Plug-in Operations

#
# $pluginmgr->relocale;
#
# update Padre's locale object to handle new plug-in l10n.
#
sub relocale {
	my $self   = shift;
	my $locale = $self->main->{locale};

	foreach my $handle ( $self->handles ) {

		# Only process enabled plug-ins
		next unless $handle->enabled;

		# Add the plug-in locale dir to search path
		if ( $handle->plugin_can('plugin_directory_locale') ) {
			my $dir = $handle->plugin->plugin_directory_locale;
			if ( defined $dir and -d $dir ) {
				$locale->AddCatalogLookupPathPrefix($dir);
			}
		}

		# Add the plug-in catalog to the locale
		my $code   = Padre::Locale::rfc4646();
		my $prefix = $handle->locale_prefix;
		$locale->AddCatalog("$prefix-$code");
	}

	return 1;
}

#
# $pluginmgr->reset_my_plugin( $overwrite );
#
# reset the my plug-in if needed. if $overwrite is set, remove it first.
#
sub reset_my_plugin {
	my $self      = shift;
	my $overwrite = shift;

	# Do not overwrite it unless stated so.
	my $dst = File::Spec->catfile(
		Padre::Constant::PLUGIN_LIB,
		'My.pm'
	);
	if ( -e $dst and not $overwrite ) {
		return;
	}

	# Find the My Plug-in
	my $src = File::Spec->catfile(
		File::Basename::dirname( $INC{'Padre/Config.pm'} ),
		'Plugin', 'My.pm',
	);
	unless ( -e $src ) {
		Carp::croak("Could not find the original My plug-in");
	}

	# Copy the My Plug-in
	unlink $dst;
	require File::Copy;
	unless ( File::Copy::copy( $src, $dst ) ) {
		Carp::croak("Could not copy the My plug-in ($src) to $dst: $!");
	}
	chmod( 0644, $dst );
}

# Disable (but don't unload) all plug-ins when Padre exits.
# Save the plug-in enable/disable states for the next start-up.
sub shutdown {
	my $self = shift;
	my $lock = $self->main->lock('DB');

	foreach my $handle ( $self->handles ) {
		if ( $handle->enabled ) {
			$handle->update( enabled => 1 );
			$self->plugin_disable($handle);

		} elsif ( $handle->disabled ) {
			$handle->update( enabled => 0 );
		}
	}

	# Remove the circular reference between the main application and
	# the plugin manager to complete the destruction.
	# This breaks encapsulation a bit, but will do for now.
	delete $self->{parent}->{plugin_manager};
	delete $self->{parent};

	return 1;
}

=pod

=head2 C<load_plugins>

Scans for new plug-ins in the user plug-in directory, in C<@INC>,
and in F<.par> files in the user plug-in directory.

Loads any given module only once, i.e. does not refresh if the
plug-in has changed while Padre was running.

=cut

sub load_plugins {
	my $self = shift;
	my $lock = $self->main->lock( 'DB', 'refresh_menu_plugins' );

	# Put the plug-in directory first in the load order
	my $plugin_dir = $self->plugin_dir;
	unless ( grep { $_ eq $plugin_dir } @INC ) {
		unshift @INC, $plugin_dir;
	}

	# Attempt to load all plug-ins in the Padre::Plugin::* namespace
	my %seen = ();
	foreach my $inc (@INC) {
		my $dir = File::Spec->catdir( $inc, 'Padre', 'Plugin' );
		next unless -d $dir;

		local *DIR;
		opendir( DIR, $dir ) or die("opendir($dir): $!");
		my @files = readdir(DIR) or die("readdir($dir): $!");
		closedir(DIR) or die("closedir($dir): $!");

		foreach (@files) {
			next unless s/\.pm$//;
			my $module = "Padre::Plugin::$_";
			next if $seen{$module}++;

			# Specifically ignore the redundant "Perl 5 Plug-in"
			next if $module eq 'Padre::Plugin::Perl5';

			$self->_load_plugin($module);
		}
	}

	# Attempt to load all plug-ins in the Acme::Padre::* namespace
	# TO DO: Put this code behind some kind of future security option,
	#       once we have one.
	foreach my $inc (@INC) {
		my $dir = File::Spec->catdir( $inc, 'Acme', 'Padre' );
		next unless -d $dir;

		local *DIR;
		opendir( DIR, $dir ) or die("opendir($dir): $!");
		my @files = readdir(DIR) or die("readdir($dir): $!");
		closedir(DIR) or die("closedir($dir): $!");

		foreach (@files) {
			next unless s/\.pm$//;
			my $module = "Acme::Padre::$_";
			next if $seen{$module}++;
			$self->_load_plugin($module);
		}
	}

	return;
}

=pod

=head2 C<reload_plugins>

For all registered plug-ins, unload them if they were loaded
and then reload them.

=cut

sub reload_plugins {
	my $self = shift;
	my $lock = $self->main->lock( 'UPDATE', 'DB', 'refresh_menu_plugins' );

	# Do not use the reload_plugin method since that
	# refreshes the menu every time.
	foreach my $module ( $self->plugin_order ) {
		$self->_unload_plugin($module);
		$self->_load_plugin($module);
		$self->enable_editors($module);
	}

	return 1;
}

=pod

=head2 C<alert_new>

The C<alert_new> method is called by the main window post-initialisation and
checks for new plug-ins. If any are found, it presents a message to
the user.

=cut

sub alert_new {
	my $self    = shift;
	my $plugins = $self->plugins;
	my @loaded  = sort
		map  { $_->plugin_name }
		grep { $_->loaded } values %$plugins;

	if ( @loaded and not $ENV{HARNESS_ACTIVE} ) {
		my $msg = Wx::gettext(<<"END_MSG") . join( "\n", @loaded );
We found several new plug-ins.
In order to configure and enable them go to
Plug-ins -> Plug-in Manager

List of new plug-ins:

END_MSG

		$self->main->message(
			$msg,
			Wx::gettext('New plug-ins detected')
		);
	}

	return 1;
}

=pod

=head2 C<failed>

Returns the list of all plugins that the editor attempted to load but
failed. Note that after a failed attempt, the plug-in is usually disabled
in the configuration and not loaded again when the editor is restarted.

=cut

sub failed {
	return map {
		$_->class
	} grep {
		$_->error or $_->incompatible
	} $_[0]->handles;
}





######################################################################
# Loading and Unloading a Plug-in

=pod

=head2 C<load_plugin>

Given a plug-in name such as C<Foo> (the part after C<Padre::Plugin>),
load the corresponding module, enable the plug-in and update the Plug-ins
menu, etc.

=cut

sub load_plugin {
	my $self = shift;
	my $lock = $self->main->lock( 'DB', 'refresh_menu_plugins' );
	$self->_load_plugin(@_);
}

# This method implements the actual mechanics of loading a plug-in,
# without regard to the context it is being called from.
# So this method doesn't do stuff like refresh the plug-in menu.
#
# NOTE: This method looks fairly long, but it's doing
# a very specific and controlled series of steps. Splitting this up
# would just make the process harder to understand, so please don't.
sub _load_plugin {
	my $self    = shift;
	my $module  = shift;
	my $main    = $self->main;
	my $plugins = $self->plugins;

	# Shortcut and skip if loaded
	return if $plugins->{$module};

	# Create the plug-in object (and flush the old sort order)
	my $handle = $plugins->{$module} = Padre::PluginHandle->new(
		class => $module,
	);
	delete $self->{plugin_order};

	# Attempt to load the plug-in
	SCOPE: {

		# Suppress warnings while loading plugins
		local $SIG{__WARN__} = sub () { };
		eval "use $module ();";
	}
	if ($@) {
		$handle->errstr(
			sprintf(
				Wx::gettext("%s - Crashed while loading: %s"),
				$module, $@,
			)
		);
		$handle->status('error');
		return;
	}

	# Is the module versioned?
	unless ( defined $module->VERSION ) {
		$handle->errstr(
			sprintf(
				Wx::gettext("%s - Plugin is empty or unversioned"),
				$module,
			)
		);
		$handle->status('error');
		return;
	}

	# Plug-in must be a Padre::Plugin subclass
	unless ( $module->isa('Padre::Plugin') ) {
		$handle->errstr(
			sprintf(
				Wx::gettext("%s - Not a Padre::Plugin subclass"),
				$module,
			)
		);
		$handle->status('error');
		return;
	}

	# Is the plugin compatible with this Padre
	my $compatible = $self->compatible($module);
	if ($compatible) {
		$handle->errstr(
			sprintf(
				Wx::gettext("%s - Not compatible with Padre %s - %s"),
				$module,
				$Padre::PluginManager::VERSION,
				$compatible,
			)
		);
		$handle->status('incompatible');
		return;
	}

	# Attempt to instantiate the plug-in
	my $plugin = eval {
		$module->new( $self->{parent} );
	};
	if ($@) {
		$handle->errstr(
			sprintf(
				Wx::gettext("%s - Crashed while instantiating: %s"),
				$module, $@,
			)
		);
		$handle->status('error');
		return;
	}
	unless ( Params::Util::_INSTANCE( $plugin, 'Padre::Plugin' ) ) {
		$handle->errstr(
			sprintf(
				Wx::gettext("%s - Failed to instantiate plug-in"),
				$module,
			)
		);
		$handle->status('error');
		return;
	}

	# Plug-in is now loaded
	$handle->{plugin} = $plugin;
	$handle->status('loaded');

	# Return unless we will enable the plugin
	unless ( $handle->db->enabled ) {
		$handle->status('disabled');
		return;
	}

	# Add a new directory for locale to search translation catalogs.
	if ( $handle->plugin_can('plugin_directory_locale') ) {
		my $dir = $plugin->plugin_directory_locale;
		if ( defined $dir and -d $dir ) {
			my $locale = $main->{locale};
			$locale->AddCatalogLookupPathPrefix($dir);
		}
	}

	# FINALLY we can enable the plug-in
	$self->plugin_enable($handle);

	return 1;
}

sub compatible {
	my $self   = shift;
	my $plugin = shift;

	# What interfaces does the plugin need
	unless ( $plugin->can('padre_interfaces') ) {
		return "$plugin does not declare Padre interface requirements";
	}
	my @needs = $plugin->padre_interfaces;

	while (@needs) {
		my $module = shift @needs;
		my $need   = shift @needs;

		# We take two different approaches to the capture of the
		# version and compatibility values depending on whether
		# the module has been loaded or not.
		my $version;
		my $compat;
		if ( Class::Inspector->loaded($module) ) {
			no strict 'refs';
			$version = ${"${module}::VERSION"}    || 0;
			$compat  = ${"${module}::COMPATIBLE"} || 0;

		} else {

			# Find the unloaded file
			my $file = Class::Inspector->resolved_filename($module);
			unless ( defined $file and length $file ) {
				return "$module is not installed or undetectable";
			}

			# Scan the unloaded file ala EU:MakeMaker
			$version = Padre::Util::parse_variable( $file, 'VERSION' );
			$compat  = Padre::Util::parse_variable( $file, 'COMPATIBLE' );

		}

		# Does the dependency meet the criteria?
		$version = 0 if $version eq 'undef';
		$compat  = 0 if $compat  eq 'undef';
		unless ( $need <= $version ) {
			return "$module is needed at newer version $need";
		}
		unless ( $need >= $compat ) {
			return "$module is not back-compatible with $need";
		}
	}

	return '';
}

=pod

=head2 C<unload_plugin>

Given a plug-in name such as C<Foo> (the part after C<Padre::Plugin>),
B<disable> the plug-in, B<unload> the corresponding module, and update the Plug-ins
menu, etc.

=cut

sub unload_plugin {
	my $self = shift;
	my $lock = $self->main->lock('refresh_menu_plugins');
	$self->_unload_plugin(@_);
}

# the guts of unload_plugin which don't refresh the menu
sub _unload_plugin {
	my $self   = shift;
	my $handle = $self->handle(shift);
	my $lock   = $self->main->lock('DB');

	# Save state and disable if needed
	if ( $handle->enabled ) {
		$handle->update( enabled => 1 );
		$handle->disable;
	} else {
		$handle->update( enabled => 0 );
	}

	# Destruct the plug-in
	if ( defined $handle->plugin ) {
		$handle->{plugin} = undef;
	}

	# Unload the plug-in class itself
	$handle->unload;

	# Finally, remove the handle (and flush the sort order)
	delete $self->{plugins}->{ $handle->class };
	delete $self->{plugin_order};

	return 1;
}

sub plugin_enable {
	my $self   = shift;
	my $handle = $self->handle(shift) or return;
	$handle->enable;
}

sub plugin_disable {
	my $self   = shift;
	my $handle = $self->handle(shift) or return;
	$handle->disable;
}

sub user_enable {
	my $self   = shift;
	my $handle = $self->handle(shift) or return;
	$handle->update( enabled => 1 );
	$self->plugin_enable($handle);
}

sub user_disable {
	my $self   = shift;
	my $handle = $self->handle(shift) or return;
	$handle->update( enabled => 0 );
	$self->plugin_disable($handle);
}

=pod

=head2 C<reload_plugin>

Reload a single plug-in whose name (without C<Padre::Plugin::>)
is passed in as first argument.

=cut

sub reload_plugin {
	my $self   = shift;
	my $handle = self->handle(shift) or return;
	my $lock   = $self->main->lock( 'UPDATE', 'DB', 'refresh_menu_plugins' );
	$self->_unload_plugin($handle);
	$self->_load_plugin($handle)   or return;
	$self->enable_editors($handle) or return;
	return 1;
}

# Fire a event on all active plugins
sub plugin_event {
	my $self  = shift;
	my $event = shift;

	foreach my $handle ( $self->handles ) {
		next unless $handle->enabled;
		next unless $handle->plugin_can($event);

		eval {
			$handle->plugin->$event(@_);
		};
		if ($@) {
			$self->_error(
				$handle,
				sprintf(
					Wx::gettext('Plugin error on event %s: %s'),
					$event,
					$@,
				)
			);
			next;
		}
	}
	return 1;
}

# Run a plugin hook
sub hook {
	my $self     = shift;
	my $hookname = shift;
	my @args     = @_;

	my $result = 1; # Default to success

	if ( ref( $self->{hooks}->{$hookname} ) eq 'ARRAY' ) {
		for my $hook ( @{ $self->{hooks}->{$hookname} } ) {

			my @retval = eval { &{ $hook->[1] }( $hook->[0], @args ); };
			if ($@) {
				warn 'Plugin ' . $hook->[0] . ', hook ' . $hookname . ', code ' . $hook->[1] . ' crashed with ' . $@;
				next;
			}

			# Return value handling depends on hook type
			if ( $PADRE_HOOKS{$hookname} == PADRE_HOOK_RETURN_ERROR ) {
				next unless defined( $retval[0] ); # Returned undef = no error
				$self->main->error(
					$retval[0] || sprintf(
						Wx::gettext('Plugin %s, hook %s returned an emtpy error message'), $hook->[0], $hookname
					)
				);
				$result = 0;
			}

		}
	}

	return $result;
}


# Show an error message
sub _error {
	my $self   = shift;
	my $plugin = shift || Wx::gettext('(core)');
	my $text   = shift || Wx::gettext('Unknown error');

	# Report detailed plugin error to console
	my @callerinfo  = caller(0);
	my @callerinfo1 = caller(1);

	print STDERR 'Plugin ', $plugin, ' error at ', $callerinfo[1] . ' line ' . $callerinfo[2],
		' in ' . $callerinfo[0] . '::' . $callerinfo1[3], ': ' . $text . "\n";

	# Report to user
	$self->main->error( sprintf( Wx::gettext('Plugin %s'), $plugin ) . ': ' . $text );
}

# Enable all the plug-ins for a single editor
sub editor_enable {
	my $self   = shift;
	my $editor = shift;
	return $self->plugin_event( 'editor_enable', $editor, $editor->{Document} );
}

sub editor_disable {
	my $self   = shift;
	my $editor = shift;
	return $self->plugin_event( 'editor_disable', $editor, $editor->{Document} );
}

sub enable_editors_for_all {
	my $self = shift;
	foreach my $handle ( $self->handles ) {
		$self->enable_editors($handle);
	}
	return 1;
}

sub enable_editors {
	my $self   = shift;
	my $handle = $self->handle(shift) or return;
	return unless $handle->enabled;
	return unless $handle->plugin_can('editor_enable');

	foreach my $editor ( $self->main->editors ) {
		local $@;
		eval {
			$handle->plugin->editor_enable( $editor, $editor->{Document} );
		};
	}

	return 1;
}





######################################################################
# Menu Integration

# Generate the menu for a plug-in
sub get_menu {
	my $self   = shift;
	my $main   = shift;
	my $handle = $self->handle(shift) or return ();
	return () unless $handle->enabled;
	return () unless $handle->plugin_can('menu_plugins');

	my @menu = eval {
		$handle->plugin->menu_plugins($main);
	};
	if ($@) {
		$handle->{status} = 'error';
		$handle->errstr(
			_T('Error when calling menu for plug-in %s: %s'),
			$handle->class,
			$@,
		);

		# TO DO: make sure these error messages show up somewhere or it will drive
		# crazy anyone trying to write a plug-in
		return ();
	}

	# Plugin provides a single menu item
	if ( @menu == 1
		and Params::Util::_INSTANCE( $menu[0], 'Wx::MenuItem' ) )
	{
		return @menu;
	}

	# Plugin provides a full submenu
	if (    @menu == 2
		and defined Params::Util::_STRING( $menu[0] )
		and Params::Util::_INSTANCE( $menu[1], 'Wx::Menu' ) )
	{
		return ( -1, @menu );
	}

	# Unrecognised or unsupported menu type
	return ();
}

=pod

=head2 C<reload_current_plugin>

When developing a plug-in one usually edits the
files belonging to the plug-in (The C<Padre::Plugin::Wonder> itself
or C<Padre::Documents::Wonder> located in the same project as the plug-in
itself.

This call and the appropriate menu option should be able to load
(or reload) that plug-in.

=cut

# TODO: Move this into the developer plugin, nobody needs this unless they
# are actively working on a Padre plugin.
sub reload_current_plugin {
	my $self     = shift;
	my $current  = $self->current;
	my $main     = $current->main;
	my $filename = $current->filename;
	my $project  = $current->project;

	# Do we have what we need?
	unless ($filename) {
		return $main->error( Wx::gettext('No filename') );
	}
	unless ($project) {
		return $main->error( Wx::gettext('Could not locate project directory.') );
	}

	# TO DO shall we relax the assumption of a lib subdir?
	my $root = $project->root;
	$root = File::Spec->catdir( $root, 'lib' );
	local @INC = ( $root, grep { $_ ne $root } @INC );

	my ($plugin_filename) = glob File::Spec->catdir( $root, 'Padre', 'Plugin', '*.pm' );

	# Load plug-in
	my $plugin = 'Padre::Plugin::' . File::Basename::basename($plugin_filename);
	$plugin =~ s/\.pm$//;

	my $plugins = $self->plugins;
	if ( $plugins->{$plugin} ) {
		$self->reload_plugin($plugin);
	} else {
		$self->load_plugin($plugin);
		if ( $self->plugins->{$plugin}->{status} eq 'error' ) {
			$main->error(
				sprintf(
					Wx::gettext("Failed to load the plug-in '%s'\n%s"),
					$plugin, $self->plugins->{$plugin}->errstr
				)
			);
			return;
		}
	}

	return;
}

=pod

=head2 C<on_context_menu>

Called by C<Padre::Wx::Editor> when a context menu is about to
be displayed. The method calls the context menu hooks in all plug-ins
that have one for plug-in specific manipulation of the context menu.

=cut

sub on_context_menu {
	my $self = shift;

	foreach my $handle ( $self->handles ) {
		next unless $handle->can_context;
		foreach my $handle ( $self->handles ) {
			$handle->plugin->event_on_context_menu(@_);
		}
	}

	return ();
}

# TO DO: document this.
# TO DO: make it also reload the file?
sub test_a_plugin {
	my $self    = shift;
	my $main    = $self->main;
	my $config  = $self->parent->config;
	my $plugins = $self->plugins;

	my $last_filename = $main->current->filename;
	my $default_dir   = '';
	if ($last_filename) {
		$default_dir = File::Basename::dirname($last_filename);
	}
	my $dialog = Wx::FileDialog->new(
		$main, Wx::gettext('Open file'), $default_dir, '', '*.*', Wx::FD_OPEN,
	);
	unless (Padre::Constant::WIN32) {
		$dialog->SetWildcard("*");
	}
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	my $filename = $dialog->GetFilename;
	$default_dir = $dialog->GetDirectory;

	# Save into plug-in for next time
	my $file = File::Spec->catfile( $default_dir, $filename );

	# Last catfile's parameter is to ensure trailing slash
	my $plugin_folder_name = qr/Padre[\\\/]Plugin[\\\/]/;
	( $default_dir, $filename ) = split( $plugin_folder_name, $file, 2 );
	unless ($filename) {
		Wx::MessageBox(
			sprintf(
				Wx::gettext("Plug-in must have '%s' as base directory"),
				$plugin_folder_name
			),
			'Error loading plug-in',
			Wx::OK, $main
		);
		return;
	}

	$filename =~ s/\.pm$//;     # Remove last .pm
	$filename =~ s/[\\\/]/\:\:/;
	unless ( $INC[0] eq $default_dir ) {
		unshift @INC, $default_dir;
	}

	# Unload any previously existant plug-in with the same name
	if ( $plugins->{$filename} ) {
		$self->unload_plugin($filename);
		delete $plugins->{$filename};
	}

	# Load the selected plug-in
	$self->load_plugin($filename);
	if ( $self->plugins->{$filename}->{status} eq 'error' ) {
		$main->error(
			sprintf(
				Wx::gettext("Failed to load the plug-in '%s'\n%s"), $filename, $self->plugins->{$filename}->errstr
			)
		);
		return;
	}

	return;
}





######################################################################
# Support Functions

sub handle {
	my $self = shift;
	my $it   = shift;

	if ( Params::Util::_INSTANCE( $it, 'Padre::PluginHandle' ) ) {
		my $current = $self->{plugins}->{ $it->class };
		unless ( defined $current ) {
			Carp::croak("Unknown plug-in '$it' provided to PluginManager");
		}
		unless ( Scalar::Util::refaddr($it) == Scalar::Util::refaddr($current) ) {
			Carp::croak("Duplicate plug-in '$it' provided to PluginManager");
		}
		return $it;
	}

	# Convert from class to name if needed
	if ( defined Params::Util::_CLASS($it) ) {
		unless ( defined $self->{plugins}->{$it} ) {
			Carp::croak("Plug-in '$it' does not exist in PluginManager");
		}
		return $self->{plugins}->{$it};
	}

	Carp::croak("Missing or invalid plug-in provided to Padre::PluginManager");
}

1;

=pod

=head1 SEE ALSO

L<Padre>, L<Padre::Config>

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

