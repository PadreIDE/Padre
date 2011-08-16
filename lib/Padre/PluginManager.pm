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
#
# MAINTAINER NOTES:
# - Don't delete the commented-out PAR-related code, we're turning it
#   back on at some point.

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
use Padre::Wx              ();
use Padre::Wx::Menu::Tools ();

our $VERSION = '0.90';





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
	my $class = shift;
	my $parent = Params::Util::_INSTANCE( shift, 'Padre' )
		or Carp::croak("Creation of a Padre::PluginManager without a Padre not possible");

	my $self = bless {
		parent                    => $parent,
		plugins                   => {},
		plugin_dir                => Padre::Constant::PLUGIN_DIR,
		plugin_order              => [],
		plugins_with_context_menu => {},

		#par_loaded               => 0,
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

=head2 C<plugins_with_context_menu>

Returns a hash (reference) with the names of all plug-ins as
keys which define a hook for the context menu.

See L<Padre::Plugin>.

=cut

use Class::XSAccessor {
	getters => {
		parent                    => 'parent',
		plugin_dir                => 'plugin_dir',
		plugins                   => 'plugins',
		plugins_with_context_menu => 'plugins_with_context_menu',
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

# Get the prefered plugin order.
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

sub plugin_objects {
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

	foreach my $plugin ( $self->plugin_objects ) {

		# Only process enabled plug-ins
		next unless $plugin->enabled;

		# Add the plug-in locale dir to search path
		my $object = $plugin->{object};
		if ( $object->can('plugin_directory_locale') ) {
			my $dir = $object->plugin_directory_locale;
			if ( defined $dir and -d $dir ) {
				$locale->AddCatalogLookupPathPrefix($dir);
			}
		}

		# Add the plug-in catalog to the locale
		my $code   = Padre::Locale::rfc4646();
		my $prefix = $plugin->locale_prefix;
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

	foreach my $module ( $self->plugin_order ) {
		my $plugin = $self->_plugin($module);
		if ( $plugin->enabled ) {
			Padre::DB::Plugin->update_enabled(
				$module => 1,
			);
			$self->plugin_disable($plugin);

		} elsif ( $plugin->disabled ) {
			Padre::DB::Plugin->update_enabled(
				$module => 0,
			);
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
	my $lock = $self->main->lock( 'UPDATE', 'DB', 'refresh_menu_plugins' );

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

	# Disabled until someone other than tsee wants to use PAR plug-ins :)
	# $self->_load_plugins_from_par;
	if ( my @failed = $self->failed ) {

		# Until such time as we can show an error message
		# in a smarter way, this gets annoying.
		# Every time you start the editor, we tell you what
		# we DIDN'T do...
		# Turn this back on once we can track these over time
		# and only report on plug-ins that USED to work but now
		# have started to fail.
		# $self->parent->wx->main->error(
		#     Wx::gettext("Failed to load the following plug-in(s):\n")
		#     . join "\n", @failed
		# ) unless $ENV{HARNESS_ACTIVE};
		return;
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
	my $plugins = $self->plugins;
	foreach my $module ( sort keys %$plugins ) {
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

		$self->parent->wx->main->message(
			$msg,
			Wx::gettext('New plug-ins detected')
		);
	}

	return 1;
}

=pod

=head2 C<failed>

Returns the plug-in names (without C<Padre::Plugin::> prefixed) of all plug-ins
that the editor attempted to load but failed. Note that after a failed
attempt, the plug-in is usually disabled in the configuration and not loaded
again when the editor is restarted.

=cut

sub failed {
	my $self    = shift;
	my $plugins = $self->plugins;
	return grep { $plugins->{$_}->status eq 'error' or $plugins->{$_}->status eq 'incompatible' } sort keys %$plugins;
}





######################################################################
# PAR Integration

# NOTE:
# Temporarily disabled until we actually start using PAR for plug-ins.
# Don't delete this code or tsee will be very sad.

## Attempt to load all plug-ins that sit as .par files in the
## .padre/plugins/ folder
#sub _load_plugins_from_par {
#    my ($self) = @_;
#    $self->_setup_par;
#
#    my $plugin_dir = $self->plugin_dir;
#    opendir my $dh, $plugin_dir or return;
#    while ( my $file = readdir $dh ) {
#        if ( $file =~ /^\w+\.par$/i ) {
#            # Only single-level plug-ins for now.
#            my $parfile = File::Spec->catfile( $plugin_dir, $file );
#            PAR->import($parfile);
#            $file =~ s/\.par$//i;
#            $file =~ s/-/::/g;
#
#            # Caller must refresh plug-in menu
#            $self->_load_plugin($file);
#        }
#    }
#    closedir($dh);
#    return;
#}
#
## Load the PAR module and setup the cache directory.
#sub _setup_par {
#    my ($self) = @_;
#
#    return if $self->{par_loaded};
#
#    # Setup the PAR environment:
#    require PAR;
#    my $plugin_dir = $self->plugin_dir;
#    my $cache_dir = File::Spec->catdir( $plugin_dir, 'cache' );
#    $ENV{PAR_GLOBAL_TEMP} = $cache_dir;
#    File::Path::mkpath($cache_dir) unless -e $cache_dir;
#    $ENV{PAR_TEMP} = $cache_dir;
#
#    $self->{par_loaded} = 1;
#}





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
	my $lock = $self->main->lock('refresh_menu_plugins');
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
	my $self   = shift;
	my $module = shift;

	# Shortcut and skip if loaded
	my $plugins = $self->plugins;
	return if $plugins->{$module};

	# Create the plug-in object (and flush the old sort order)
	my $plugin = $plugins->{$module} = Padre::PluginHandle->new(
		class => $module,
	);
	delete $self->{plugin_order};

	# Attempt to load the plug-in
	SCOPE: {

		# Suppress warnings while loading plugins
		local $SIG{__WARN__} = sub () { };
		eval "use $module ();";
	}

	# Did it compile?
	if ($@) {
		$plugin->errstr(
			sprintf(
				Wx::gettext("%s - Crashed while loading: %s"),
				$module, $@,
			)
		);
		$plugin->status('error');
		return;
	}

	unless ( defined $module->VERSION ) {
		$plugin->errstr(
			sprintf(
				Wx::gettext("%s - Plugin is empty or unversioned"),
				$module,
			)
		);
		$plugin->status('error');
		return;
	}

	# Plug-in must be a Padre::Plugin subclass
	unless ( $module->isa('Padre::Plugin') ) {
		$plugin->errstr(
			sprintf(
				Wx::gettext("%s - Not a Padre::Plugin subclass"),
				$module,
			)
		);
		$plugin->status('error');
		return;
	}

	# Is the plugin compatible with this Padre
	my $compatible = $self->compatible($module);
	if ($compatible) {
		$plugin->errstr(
			sprintf(
				Wx::gettext("%s - Not compatible with Padre %s - %s"),
				$module,
				$Padre::PluginManager::VERSION,
				$compatible,
			)
		);
		$plugin->status('incompatible');
		return;
	}

	# Attempt to instantiate the plug-in
	my $object = eval { $module->new( $self->{parent} ); };
	if ($@) {
		$plugin->errstr(
			sprintf(
				Wx::gettext("%s - Crashed while instantiating: %s"),
				$module, $@,
			)
		);
		$plugin->status('error');
		return;
	}
	unless ( Params::Util::_INSTANCE( $object, 'Padre::Plugin' ) ) {
		$plugin->errstr(
			sprintf(
				Wx::gettext("%s - Failed to instantiate plug-in"),
				$module,
			)
		);
		$plugin->status('error');
		return;
	}

	# Plug-in is now loaded
	$plugin->{object} = $object;
	$plugin->status('loaded');

	# Should we try to enable the plug-in
	my $config = $self->plugin_db( $plugin->class );
	unless ( defined $config->enabled ) {

		# Do not enable by default
		$config->set( enabled => 0 );
	}

	# NOTE: This violates encapsulation. The plugin manager should be
	# manipulated from the outside, it shouldn't introspect it's parent IDE
	unless ( $config->enabled ) {
		$plugin->status('disabled');
		return;
	}

	# Add a new directory for locale to search translation catalogs.
	if ( $object->can('plugin_directory_locale') ) {
		my $dir = $object->plugin_directory_locale;
		if ( defined $dir and -d $dir ) {
			my $locale = $self->main->{locale};
			$locale->AddCatalogLookupPathPrefix($dir);
		}
	}

	# FINALLY we can enable the plug-in
	$self->plugin_enable($plugin);

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
			unless ( defined $file ) {
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
	my $handle = $self->_plugin(shift);
	my $module = $handle->class;

	# Remember if we are enabled or not
	my $enabled = $handle->enabled ? 1 : 0;
	Padre::DB::Plugin->update_enabled(
		$module => $enabled,
	);

	# Disable if needed
	if ( $handle->enabled ) {
		$handle->disable;
	}

	# Destruct the plug-in
	if ( defined $handle->{object} ) {
		$handle->{object} = undef;
	}

	# Unload the plug-in class itself
	require Class::Unload;
	Class::Unload->unload($module);

	# Finally, remove the handle (and flush the sort order)
	delete $self->{plugins}->{$module};
	delete $self->{plugin_order};

	return 1;
}

sub plugin_enable {
	my $self   = shift;
	my $module = shift;
	my $handle = $self->_plugin($module) or return;
	my $result = $handle->enable;

	# Update the last-enabled version each time it is enabled
	Padre::DB::Plugin->update_version(
		$module => $handle->version,
	);

	return $result;
}

sub plugin_disable {
	my $self = shift;
	my $handle = $self->_plugin(shift) or return;
	$handle->disable;
}

=pod

=head2 C<reload_plugin>

Reload a single plug-in whose name (without C<Padre::Plugin::>)
is passed in as first argument.

=cut

sub reload_plugin {
	my $self   = shift;
	my $lock   = $self->main->lock( 'UPDATE', 'DB', 'refresh_menu_plugins' );
	my $module = shift;
	$self->_unload_plugin($module);
	$self->_load_plugin($module)   or return;
	$self->enable_editors($module) or return;
	return 1;
}

=pod

=head2 C<plugin_db>

Given a plug-in name or namespace, returns a hash reference
which corresponds to the configuration section in the Padre
database of that plug-in. Any modifications of that
hash reference will, on normal exit, be serialized and
written back to the database file.

If the plug-in name is omitted and this method is called from
a plug-in namespace, the plug-in name is determine automatically.

=cut

sub plugin_db {
	my $self   = shift;
	my $module = shift;

	# Infer the plug-in name from caller if not provided
	unless ( defined $module ) {
		my ($package) = caller();
		unless ( $package =~ /^Padre::Plugin::/ ) {
			Carp::croak("Cannot infer the name of the plug-in for which the configuration has been requested");
		}
		$module = $package;
	}

	# Get the plug-in, and from there the config
	my $plugin = $self->_plugin($module);
	my @object = Padre::DB::Plugin->select( 'where name = ?', $module );
	return $object[0] if @object;
	return Padre::DB::Plugin->create(
		name => $plugin->class,

		# Track the last version of the plugin that we were
		# able to successfully enable (nothing to start with)
		version => undef,

		# Having undef here means no preference yet
		enabled => undef,
		config  => undef,
	);
}

# Fire a event on all active plugins
sub plugin_event {
	my $self  = shift;
	my $event = shift;

	foreach my $module ( keys %{ $self->{plugins} } ) {

		# TODO: Re-enable the commented out error messages when the failing modules
		#       are fixed.

		my $plugin = $self->{plugins}->{$module};
		if ( !ref($plugin) ) {

			# $self->_error($plugin,Wx::gettext('Not found in plugin list!'));
			next;
		}

		my $object = $plugin->{object};
		if ( !ref($object) ) {

			# $self->_error($plugin,Wx::gettext('Plugin object missing!'));
			next;
		}

		next unless $plugin->{status};
		next unless $plugin->{status} eq 'enabled';

		eval {
			return if not $object->can($event);
			$object->$event(@_);
		};
		if ($@) {
			$self->_error( $plugin, sprintf( Wx::gettext('Plugin error on event %s: %s'), $event, $@ ) );
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

	#	foreach my $module ( keys %{ $self->{plugins} } ) {
	#		my $plugin = $self->{plugins}->{$module} or return;
	#		my $object = $plugin->{object}           or return;
	#		next unless $plugin->{status};
	#		next unless $plugin->{status} eq 'enabled';
	#		eval {
	#			return if not $object->can('editor_enable');
	#			$object->editor_enable( $editor, $editor->{Document} );
	#		};
	#		if ($@) {
	#			warn $@;
	#
	#			# TO DO: report the plug-in error!
	#		}
	#	}
	#	return;

	return $self->plugin_event( 'editor_enable', $editor, $editor->{Document} );
}

sub editor_disable {
	my $self   = shift;
	my $editor = shift;
	return $self->plugin_event( 'editor_disable', $editor, $editor->{Document} );
}

sub enable_editors_for_all {
	my $self    = shift;
	my $plugins = $self->plugins;
	foreach my $module ( keys %$plugins ) {
		$self->enable_editors($module);
	}
	return 1;
}

sub enable_editors {
	my $self   = shift;
	my $module = shift;
	my $plugin = $self->plugins->{$module} or return;
	my $object = $plugin->{object} or return;
	return unless ( $plugin->{status} and $plugin->{status} eq 'enabled' );
	foreach my $editor ( $self->main->editors ) {
		if ( $object->can('editor_enable') ) {
			$object->editor_enable( $editor, $editor->{Document} );
		}
	}
	return 1;
}





######################################################################
# Menu Integration

# Generate the menu for a plug-in
sub get_menu {
	my $self   = shift;
	my $main   = shift;
	my $module = shift;

	my $plugin = $self->_plugin($module);
	return () unless $plugin and $plugin->{status} eq 'enabled';
	return () unless $plugin->{object}->can('menu_plugins');

	my @menu = eval { $plugin->{object}->menu_plugins($main) };
	if ($@) {
		$plugin->errstr( Wx::gettext('Error when calling menu for plug-in ') . "'$module': $@" );
		$plugin->{status} = 'error';

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
	my $self    = shift;
	my $plugins = $self->plugins_with_context_menu;
	return if not keys %$plugins;

	my ( $doc, $editor, $menu, $event ) = @_;

	my $plugin_handles = $self->plugins;
	foreach my $plugin_name ( keys %$plugins ) {
		my $plugin = $plugin_handles->{$plugin_name}->object;
		$plugin->event_on_context_menu( $doc, $editor, $menu, $event );
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
		$main, Wx::gettext('Open file'), $default_dir, '', '*.*', Wx::wxFD_OPEN,
	);
	unless (Padre::Constant::WIN32) {
		$dialog->SetWildcard("*");
	}
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
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
			Wx::wxOK, $main
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

sub _plugin {
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

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

