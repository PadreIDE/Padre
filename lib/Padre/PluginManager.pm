package Padre::PluginManager;

# API NOTES:
# This class uses english-style verb_noun method naming

=pod

=head1 NAME

Padre::PluginManager - Padre plugin manager

=head1 DESCRIPTION

The PluginManager class contains logic for locating and loading Padre
plugins, as well as providing part of the interface to plugin writers.

=head1 METHODS

=cut

use strict;
use warnings;
use Carp                     qw{croak};
use File::Path               ();
use File::Spec               ();
use Scalar::Util             ();
use Params::Util             qw{_IDENTIFIER _CLASS _INSTANCE};
use Padre::Util              ();
use Padre::PluginHandle      ();
use Padre::Wx                ();
use Padre::Wx::Menu::Plugins ();

our $VERSION = '0.22';





#####################################################################
# Constructor and Accessors

=pod

=head2 new

The constructor returns a new Padre::PluginManager object, but
you should normally access it via the main Padre object:

  my $manager = Padre->ide->plugin_manager;

First argument should be a Padre object.

=cut

sub new {
	my $class  = shift;
	my $parent = shift || Padre->ide;

	unless ( _INSTANCE($parent, 'Padre') ) {
		croak("Creation of a Padre::PluginManager without a Padre not possible");
	}

	my $self = bless {
		parent       => $parent,
		plugins      => {},
		plugin_names => [],
		plugin_dir   => Padre::Config->default_plugin_dir,
		par_loaded   => 0,
		@_,
	}, $class;

	return $self;
}

=pod

=head2 parent

Stores a reference back to the parent IDE object.

=head2 plugin_dir

Returns the user plugin directory (below the Padre configuration directory).
This directory was added to the C<@INC> module search path and may contain
packaged plugins as PAR files.

=head2 plugins

Returns a hash (reference) of plugin names associated with a
L<Padre::PluginHandle>.

This hash is only populated after C<load_plugins()> was called.

=cut

use Class::XSAccessor
	getters => {
		parent     => 'parent',
		plugin_dir => 'plugin_dir',
		plugins    => 'plugins',
	};

# Get the prefered plugin order.
# The order calculation cost is higher than we might like,
# so cache the result.
sub plugin_names {
	my $self = shift;
	unless ( $self->{plugin_names} ) {
		$self->{plugin_names} = [
			sort {
				($b->name eq 'My') <=> ($a->name eq 'My')
				or
				$a->name cmp $b->name
			}
			values %{ $self->{plugins} }
		];
	}
	return @{ $self->{plugin_names} };
}

sub plugin_objects {
	grep { $_[0]->{plugins}->{$_} } $_[0]->plugin_names;
}





#####################################################################
# Bulk Plugin Operations

=pod

=head2 reload_plugins

For all registered plugins, unload them if they were loaded
and then reload them.

=cut

sub reload_plugins {
	my $self    = shift;
	my $plugins = $self->plugins;
	foreach my $name ( sort keys %$plugins ) {
		# do not use the reload_plugin method since that
		# refreshes the menu every time.
		$self->_unload_plugin($name);
		$self->_load_plugin($name);
		$self->enable_editors($name);
	}
	$self->_refresh_plugin_menu;
	return 1;
}

=pod

=head2 load_plugins

Scans for new plugins in the user plugin directory, in C<@INC>,
and in C<.par> files in the user plugin directory.

Loads any given module only once, i.e. does not refresh if the
plugin has changed while Padre was running.

=cut

sub load_plugins {
	my $self = shift;
	$self->_load_plugins_from_inc;
	$self->_load_plugins_from_par;
	$self->_refresh_plugin_menu;
	if ( my @failed = $self->failed ) {
		# Until such time as we can show an error message
		# in a smarter way, this gets annoying.
		# Every time you start the editor, we tell you what
		# we DIDN'T do...
		# Turn this back on once we can track these over time
		# and only report on plugins that USED to work but now
		# have started to fail.
		#$self->parent->wx->main_window->error(
		#	Wx::gettext("Failed to load the following plugin(s):\n")
		#	. join "\n", @failed
		#) unless $ENV{HARNESS_ACTIVE};
		return;
	}
	return;
}

# attempt to load all plugins that sit as .pm files in the
# .padre/plugins/Padre/Plugin/ folder
sub _load_plugins_from_inc {
	my ($self) = @_;

	# Try the plugin directory first:
	my $plugin_dir = $self->plugin_dir;
	unless ( grep { $_ eq $plugin_dir } @INC ) {
		unshift @INC, $plugin_dir;
	}

	my @dirs = grep { -d $_ } map { File::Spec->catdir($_, 'Padre', 'Plugin') } @INC;

	require File::Find::Rule;
	my @files = File::Find::Rule->file->name('*.pm')->maxdepth(1)->in( @dirs );
	foreach my $file ( @files ) {
		# Full path filenames
		my $module = $file;
		$module =~ s/\.pm$//;
		$module =~ s{^.*Padre[/\\]Plugin\W*}{};
		$module =~ s{[/\\]}{::}g;

		# TODO maybe we should report to the user the fact
		# that we changed the name of the MY plugin and she should
		# rename the original one and remove the MY.pm from his installation
		if ( $module eq 'MY') {
			warn "Deprecated Padre::Plugin::MY found at $file. Please remove it\n";
			return;
		}

		# Caller must refresh plugin menu
		$self->_load_plugin($module);
	}

	return;
}

=pod

=head2 alert_new

The C<alert_new> method is called by the main window post-init and
checks for new plugins. If any are found, it presents a message to
the user.

=cut

sub alert_new {
	my $self    = shift;
	my $plugins = $self->plugins;
	my @loaded  = sort
		map  { $_->plugin_name }
		grep { $_->loaded      }
		values %$plugins;
	if ( @loaded and not $ENV{HARNESS_ACTIVE} ) {
		my $msg = Wx::gettext(<<"END_MSG") . join("\n", @loaded);
We found several new plugins.
In order to configure and enable them go to
Plugins -> Plugin Manager

List of new plugins:

END_MSG

		$self->parent->wx->main_window->message( $msg,
			Wx::gettext('New plugins detected')
		);
	}

	return 1;
}

=pod

=head2 failed

Returns the plugin names (without C<Padre::Plugin::> prefixed) of all plugins
that the editor attempted to load but failed. Note that after a failed
attempt, the plugin is usually disabled in the configuration and not loaded
again when the editor is restarted.

=cut

sub failed {
	my $self    = shift;
	my $plugins = $self->plugins;
	return grep {
		$plugins->{$_}->{status} eq 'error'
	} keys %$plugins;
}





######################################################################
# PAR Integration

# Attempt to load all plugins that sit as .par files in the
# .padre/plugins/ folder
sub _load_plugins_from_par {
	my ($self) = @_;
	$self->_setup_par;

	my $plugin_dir = $self->plugin_dir;
	opendir my $dh, $plugin_dir or return;
	while ( my $file = readdir $dh ) {
		if ( $file =~ /^\w+\.par$/i ) {
			# Only single-level plugins for now.
			my $parfile = File::Spec->catfile($plugin_dir, $file);
			PAR->import($parfile);
			$file =~ s/\.par$//i;
			$file =~ s/-/::/g;

			# Caller must refresh plugin menu
			$self->_load_plugin($file);
		}
	}
	closedir($dh);
	return;
}

# Load the PAR module and setup the cache directory.
sub _setup_par {
	my ($self) = @_;

	return if $self->{par_loaded};

	# Setup the PAR environment:
	require PAR;
	my $plugin_dir = $self->plugin_dir;
	my $cache_dir  = File::Spec->catdir($plugin_dir, 'cache');
	$ENV{PAR_GLOBAL_TEMP} = $cache_dir;
	File::Path::mkpath($cache_dir) if not -e $cache_dir;
	$ENV{PAR_TEMP} = $cache_dir;

	$self->{par_loaded} = 1;
}




######################################################################
# Loading and Unloading a Plugin

=pod

=head2 load_plugin

Given a plugin name such as C<Foo> (the part after Padre::Plugin),
load the corresponding module, enable the plugin and update the Plugins
menu, etc.

=cut

sub load_plugin {
	my $self = shift;
	my $ret = $self->_load_plugin(@_);
	$self->_refresh_plugin_menu;
	return $ret;
}

# This method implements the actual mechanics of loading a plugin,
# without regard to the context it is being called from.
# So this method doesn't do stuff like refresh the plugin menu.
#
# MAINTAINER NOTE: This method looks fairly long, but it's doing
# a very specific and controlled series of steps. Splitting this up
# would just make the process hardner to understand, so please don't.
sub _load_plugin {
	my $self = shift;
	my $name = shift;

	# If this plugin is already loaded, shortcut and skip
	$name =~ s/^Padre::Plugin:://;
	if ( $self->plugins->{$name} ) {
		return;
	}

	# Create the plugin object (and flush the old sort order)
	my $module = "Padre::Plugin::$name";
	my $plugin = $self->{plugins}->{$name} = Padre::PluginHandle->new(
		name  => $name,
		class => $module,
	);
	delete $self->{plugin_names};

	# Does the plugin load without error
	my $code = "use $module ();";
	eval $code; ## no critic
	if ( $@ ) {
		$self->{errstr} = sprintf(
			Wx::gettext(
				"Plugin:%s - Failed to load module: %s"
			),
			$name,
			$@,
		);
		$plugin->status('error');
		return;
	}

	# Plugin must be a Padre::Plugin subclass
	unless ( $module->isa('Padre::Plugin') ) {
		$self->{errstr} = sprintf(
			Wx::gettext(
				"Plugin:%s - Not compatible with Padre::Plugin API. "
				. "Need to be subclass of Padre::Plugin"
			), $name,
		);
		$plugin->status('error');
		return;
	}

	# Does the plugin have new method?
	unless ( $module->can('new') ) {
		$self->{errstr} = sprintf(
			Wx::gettext(
				"Plugin:%s - Not compatible with Padre::Plugin API. "
				. "Plugin cannot be instantiated"
			), $name,
		);
		$plugin->status('error');
		return;
	}

	# This will not check anything as padre_interfaces is defined in Padre::Plugin
	unless ( $module->can('padre_interfaces') ) {
		$self->{errstr} = sprintf(
			Wx::gettext(
				"Plugin:%s - Not compatible with Padre::Plugin API. "
				. "Need to have sub padre_interfaces"
			),
			$name,
		);
		$plugin->status('error');
		return;
	}

	# Attempt to instantiate the plugin
	my $object = eval { $module->new };
	if ( $@ ) {
		# TODO report error in a nicer way
		$self->{errstr} = $@;
		$plugin->status('error');
		return;
	}
	unless ( _INSTANCE($object, 'Padre::Plugin') ) {
		$self->{errstr} = sprintf(
			Wx::gettext(
				"Plugin:%s - Not compatible with Padre::Plugin API. "
				. "Need to have sub padre_interfaces"
			),
			$name,
		);
		$plugin->status('error');
		return;
	}

	# Plugin is now loaded
	$plugin->{object} = $object;
	$plugin->status('loaded');

	# Should we try to enable the plugin
	my $config = $self->plugin_config($plugin);
	unless ( defined $config->{enabled} ) {
		# Do not enable by default
		$config->{enabled} = 0;
	}
	unless ( $config->{enabled} ) {
		$plugin->status('disabled');
		return;
	}

	# FINALLY we are clear to enable the plugin
	$plugin->enable;

	return 1;
}

=pod

=head2 unload_plugin

Given a plugin name such as C<Foo> (the part after Padre::Plugin),
DISable the plugin, UNload the corresponding module, and update the Plugins
menu, etc.

=cut

sub unload_plugin {
	my $self = shift;
	my $ret  = $self->_unload_plugin(@_);
	$self->_refresh_plugin_menu;
	return $ret;
}

# the guts of unload_plugin which don't refresh the menu
sub _unload_plugin {
	my $self   = shift;
	my $handle = $self->_plugin(shift);

	# Remember if we are enabled or not
	$self->plugin_config($handle)->{enabled} = $handle->enabled ? 1 : 0;
	
	# Disable if needed
	if ( $handle->enabled ) {
		$handle->disable;
	}

	# Destruct the plugin
	if ( defined $handle->{object} ) {
		$handle->{object} = undef;
	}

	# Unload the plugin class itself
	require Class::Unload;
	Class::Unload->unload($handle->class);

	# Finally, remove the handle (and flush the sort order)
	delete $self->{plugins}->{$handle->name};
	delete $self->{plugin_names};

	return 1;
}

=pod

=head2 reload_plugin

Reload a single plugin whose name (without C<Padre::Plugin::>)
is passed in as first argument.

=cut

sub reload_plugin {
	my $self = shift;
	my $name = shift;
	$self->_unload_plugin($name);
	$self->load_plugin($name)    or return;
	$self->enable_editors($name) or return;
	return 1;
}





#####################################################################
# Enabling and Disabling a Plugin

# Assume the named plugin exists, enable it
sub _plugin_enable {
	$_[0]->_plugin($_[1])->enable;
}

# Assume the named plugin exists, disable it
sub _plugin_disable {
	$_[0]->_plugin($_[1])->disable;
}

=pod

=head2 plugin_config

Given a plugin name or namespace, returns a hash reference
which corresponds to the configuration section in the Padre
YAML configuration of that plugin. Any modifications of that
hash reference will, on normal exit, be written to the
configuration file.

If the plugin name is omitted and this method is called from
a plugin namespace, the plugin name is determine automatically.

=cut

sub plugin_config {
	my $self = shift;

	# Infer the plugin name from caller if not provided
	my $param = shift;
	unless ( defined $param ) {
		my ($package) = caller();
		unless ( $package =~ /^Padre::Plugin::/ ) {
			croak("Cannot infer the name of the plugin for which the configuration has been requested");
		}
		$param = $package;
	}

	# Get the plugin, and from there he config
	my $plugin  = $self->_plugin($param);
	my $config  = $self->parent->config;
	return( $config->{plugins} ||= {} );
}

# enable all the plugins for a single editor
sub editor_enable {
	my ($self, $editor) = @_;
	foreach my $name ( keys %{ $self->{plugins} } ) {
		my $plugin = $self->{plugins}->{$name} or return;
		my $object = $plugin->{object}         or return;
		next unless $plugin->{status};
		next unless $plugin->{status} eq 'enabled';
		eval {
			return if not $object->can('editor_enable');
			$object->editor_enable( $editor, $editor->{Document} );
		};
		if ( $@ ) {
			warn $@;
			# TODO: report the plugin error!
		}
	}
	return;
}

sub enable_editors_for_all {
	my $self    = shift;
	my $plugins = $self->plugins;
	foreach my $name ( keys %$plugins ) {
		$self->enable_editors($name);
	}
	return 1;
}

sub enable_editors {
	my $self   = shift;
	my $name   = shift;
	my $plugin = $self->plugins->{$name} or return;
	my $object = $plugin->{object}       or return;
	return unless ( $plugin->{status} and $plugin->{status} eq 'enabled' );
	foreach my $editor ( $self->parent->wx->main_window->pages ) {
		if ( $object->can('editor_enable') ) {
			$object->editor_enable( $editor, $editor->{Document} );
		}
	}
	return 1;
}





######################################################################
# Menu Integration

# Generate the menu for a plugin
sub get_menu {
	my $self    = shift;
	my $main    = shift;
	my $name    = shift;
	my $plugin  = $self->plugins->{$name};
	unless ( $plugin and $plugin->{status} eq 'enabled' ) {
		return ();
	}
	unless ( $plugin->{object}->can('menu_plugins') ) {
		return ();
	}
	my ($label, $menu) = eval {
		$plugin->{object}->menu_plugins($main)
	};
	if ( $@ ) {
		$self->{errstr} = "Error when calling menu for plugin '$name' $@";
		return ();
	}
	unless ( defined $label and defined $menu ) {
		return ();
	}
	return ($label, $menu);
}

# TODO: document this.
sub test_a_plugin {
	my $self    = shift;
	my $main    = $self->parent->wx->main_window;
	my $config  = $self->parent->config;
	my $plugins = $self->plugins;

	my $last_filename = $config->{last_test_plugin_file};
	$last_filename  ||= $main->selected_filename;
	my $default_dir = '';
	if ( $last_filename ) {
		$default_dir = File::Basename::dirname($last_filename);
	}
	my $dialog = Wx::FileDialog->new(
		$main, Wx::gettext('Open file'), $default_dir, '', '*.*', Wx::wxFD_OPEN,
	);
	unless ( Padre::Util::WIN32 ) {
		$dialog->SetWildcard("*");
	}
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $filename = $dialog->GetFilename;
	$default_dir = $dialog->GetDirectory;
	
	# Save into plugin for next time
	my $file = File::Spec->catfile($default_dir, $filename);
	$config->{last_test_plugin_file} = $file;
	
	( $default_dir, $filename ) = split(/Padre[\\\/]Plugin[\\\/]/, $file, 2);
	$filename =~ s/\.pm$//; # remove last .pm
	$filename =~ s/[\\\/]/\:\:/;
	unless ( $INC[0] eq $default_dir ) {
		unshift @INC, $default_dir;
	}

	# Load plugin
	delete $plugins->{$filename};
	$config->{plugins}->{$filename}->{enabled} = 1;
	$self->load_plugin($filename);
	if ( $self->plugins->{$filename}->{status} eq 'error' ) {
		$main->error(sprintf(Wx::gettext("Failed to load the plugin '%s'\n%s"), $filename, $self->{errstr}));
		return;
	}

	#$self->reload_plugins;
}

# Refresh the Plugins menu
sub _refresh_plugin_menu {	
        $_[0]->parent->wx->main_window->menu->plugins->refresh;
}





######################################################################
# Support Functions

sub _plugin {
	my ($self, $it) = @_;
	if ( _INSTANCE($it, 'Padre::PluginHandle') ) {
		my $current = $self->{plugins}->{$it->name};
		unless ( defined $current ) {
			croak("Unknown plugin '$it' provided to PluginManager");
		}
		unless (
			Scalar::Util::refaddr($it)
			==
			Scalar::Util::refaddr($current)
		) {
			croak("Duplicate plugin '$it' provided to PluginManager");
		}
		return $it;
	}
	if ( defined _CLASS($it) ) {
		# Convert from class to name if needed
		$it =~ s/^Padre::Plugin:://;
	}
	if ( _IDENTIFIER($it) ) {
		unless ( defined $self->{plugins}->{$it} ) {
			croak("Plugin '$it' does not exist in PluginManager");
		}
		return $self->{plugins}->{$it};
	}
	croak("Missing or invalid plugin provided to Padre::PluginManager");
}

1;

__END__

=pod

=head1 SEE ALSO

L<Padre>, L<Padre::Config>

L<PAR> for more on the plugin system.

=head1 COPYRIGHT

Copyright 2008 Gabor Szabo.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

