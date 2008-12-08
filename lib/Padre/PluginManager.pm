package Padre::PluginManager;

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
use Carp        qw(croak);
use File::Path  ();
use File::Spec  ();
use Padre::Util ();
use Padre::Wx   ();

our $VERSION = '0.20';





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

	if ( not $parent or not $parent->isa("Padre") ) {
		croak("Creation of a Padre::PluginManager without a Padre not possible");
	}

	my $self = bless {
		parent     => $parent,
		plugins    => {},
		plugin_dir => Padre::Config->default_plugin_dir,
		par_loaded => 0,
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

Returns a hash (reference) of plugin names associated with a plugin manager
internal structure describing the state of the plugin in the current
editor. The contents are somewhat in flux and considered mostly B<PRIVATE>,
but the following will likely stay:

=over 2

=item module

Full name of the module that implements the plugin, i.e. C<Padre::Plugin::Foo>.

=item status

The status of the plugin. C<failed> indicates failure while trying to load
the module. C<new> indicates it was detected as a new plugin.
C<loaded> indicates that the module has been successfully loaded, and
C<disabled> indicates that it isn't being used as it's been disabled
in the configuration.

Note that this concerns the status of the module in memory. Whether or
not to load the plugin is kept in the B<configuration> instead to make
it persistent. To check whether a given plugin is enabled, do this:

  if ( Padre->ide->config->{plugins}->{$name}->{enabled} ) {...}

=item object

The actual C<Padre::Plugin::Foo> object. Availability depends on the C<status>,
of course. The other keys are kept separate since the plugin object is the
sole domain of the plugin writer. We don't want them to wreak havoc on
our meta data, now do we?

=back

This hash is only populated after C<load_plugins()> was called.

=cut

use Class::XSAccessor
	getters => {
		parent     => 'parent',
		plugin_dir => 'plugin_dir',
                plugins    => 'plugins',
	};


#####################################################################
# Configuration and Startup

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
	my $self   = shift;
	my $plugin = shift;

	# infer the plugin name from caller
	if ( not defined $plugin ) {
		my ($package) = caller();
		croak("Cannot infer the name of the plugin for which the configuration has been requested")
			if $package !~ /^Padre::Plugin::/;
		$plugin = $package;
	}

	$plugin =~ s/^Padre::Plugin:://;
	my $config  = $self->parent->config;
	my $plugins = $config->{plugins};
	$plugins->{$plugin} ||= {};
	return $plugins->{$plugin};
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
		$self->parent->wx->main_window->error(
			"Failed to load the following plugin(s):\n"
			. join "\n", @failed
		);
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
	unshift @INC, $plugin_dir unless grep { $_ eq $plugin_dir } @INC;
	
	my @dirs = grep {-d $_} map {File::Spec->catdir($_, 'Padre', 'Plugin')} @INC;

	require File::Find::Rule;
	my @files = File::Find::Rule->file->name('*.pm')->maxdepth(1)->in( @dirs );
	foreach my $file (@files) {
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

		# caller must refresh plugin menu
		$self->_load_plugin_norefresh_menu($module);
	}

	return;
}

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

			# caller must refresh plugin menu
			$self->_load_plugin_norefresh_menu($file);
		}
	}
	closedir($dh);
	return;
}

# Load the PAR module and setup the cache directory.
sub _setup_par {
	my ($self) = @_;

	return if $self->{par_loaded};

	require PAR;
	# setup the PAR environment:
	my $plugin_dir = $self->plugin_dir;
	my $cache_dir = File::Spec->catdir($plugin_dir, 'cache');
	$ENV{PAR_GLOBAL_TEMP} = $cache_dir;
	File::Path::mkpath($cache_dir) if not -e $cache_dir;
	$ENV{PAR_TEMP} = $cache_dir;

	$self->{par_loaded} = 1;
	return();
}

=pod

=head2 load_plugin

Given a plugin name such as C<Foo> (the part after Padre::Plugin),
load the corresponding module, enable the plugin and update the Plugins
menu, etc.

=cut

sub load_plugin {
	my $self = shift;
	my $ret = $self->_load_plugin_norefresh_menu(@_);
	$self->_refresh_plugin_menu;
	return $ret;
}

# The guts of load_plugin which don't refresh the menu
sub _load_plugin_norefresh_menu {
	my $self    = shift;
	my $name    = shift;
	my $config  = $self->parent->config;
	my $plugins = $self->plugins;

	# Skip if that plugin was already loaded
	$name =~ s/^Padre::Plugin:://;
	if ( $plugins->{$name} and $plugins->{$name}->{status} eq 'loaded' ) {
		return;
	}

	$plugins->{$name} ||= {};
	my $state = $plugins->{$name};

	my $module = "Padre::Plugin::$name";
	$state->{module} = $module;

	unless ( $config->{plugins}->{$name} ) {
		$config->{plugins}->{$name}->{enabled} = 0;
		$state->{status} = 'new';
		return;
	}
	unless ( $config->{plugins}->{$name}->{enabled} ) {
		$state->{status} = 'disabled';
		return;
	}

	eval "use $module"; ## no critic
	if ( $@ ) {
		warn $self->{errstr} = "ERROR while trying to load plugin '$name': $@";
		$state->{status} = 'failed';
		return;
	}

	eval {
		$state->{object} = $module->new;
		unless ( ref($state->{object}) ) {
			die "Could not create plugin object for $module";
		}
		$self->_plugin_enable($name);
	};
	if ( $@ ) {
		# TODO report error in a nicer way
		warn $self->{errstr} = $@;
		$state->{status} = 'failed';

		# Automatically disable the plugin
		$config->{plugins}->{$name}->{enabled} = 0; # persistent!
	} else {
		$state->{status} = 'loaded';
	}
	
	return 1;
}

# Assume the named plugin exists, load it
sub _plugin_enable {
	my $self   = shift;
	my $name   = shift;
	my $plugin = $self->plugins->{$name}->{object};

	# Call the plugin's own enable method
	$plugin->plugin_enable;

	# If the plugin defines document types, enable them
	my @documents = $plugin->registered_documents;
	if ( @documents ) {
		Class::Autouse->load('Padre::Document');
	}
	while ( @documents ) {
		my $type  = shift @documents;
		my $class = shift @documents;
		$Padre::Document::MIME_CLASS{$type} = $class;
	}

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
	my $self = shift;
	my $name = shift;

	# normalize to plugin name only
	$name =~ s/^Padre::Plugin:://;
	my $config = $self->parent->config;
	my $plugins = $self->plugins;

	return if not defined $plugins->{$name}->{object};

	eval {
		$plugins->{$name}->{object}->plugin_disable;
	};
	if ($@) {
		warn $self->{errstr} = $@;
		$plugins->{$name}->{status} = 'failed';
		# automatically disable the plugin
		$config->{plugins}->{$name}->{enabled} = 0; # persistent!
	} else {
		$plugins->{$name}->{status} = 'disabled';
	}
	

	delete $plugins->{$name};

	require Class::Unload;
	Class::Unload->unload("Padre::Plugin::$name");

	return 1;
}

=pod

=head2 reload_plugins

For all registered plugins, unload them if they were loaded
and then reload them.

=cut

sub reload_plugins {
	my $self    = shift;
	my $plugins = $self->plugins;

	foreach my $name (sort keys %$plugins) {
		# do not use the reload_plugin method since that
		# refreshes the menu every time
		$self->_unload_plugin($name);
		$self->_load_plugin_norefresh_menu($name);
		$self->enable_editors($name);
	}
	$self->_refresh_plugin_menu();
	return 1;
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

	my $new_plugins  = '';
	foreach my $name ( sort keys %$plugins ) {
		if ( $plugins->{$name}->{status} eq 'new' ) {
			$new_plugins .= "$name\n";
		}
	}
	if ( $new_plugins ) {
		my $msg = <<"END_MSG";
We found several new plugins.
In order to configure and enable them go to
Plugins -> Plugin Manager

List of new plugins:

$new_plugins
END_MSG

		$self->parent->wx->main_window->message($msg, 'New plugins detected');
	}

	return 1;
}





#####################################################################
# Enable and Disable

# enable all the plugins for a single editor
sub editor_enable {
	my ($self, $editor) = @_;
	foreach my $plugin ( keys %{ $self->{plugins} } ) {
		eval {
			if ( my $object = $self->{plugins}->{$plugin}->{object} ) {
				return if not $object->can('editor_enable');
				$object->editor_enable( $editor, $editor->{Document} );
			}
		};
		if ($@) {
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
	my $self = shift;
	my $name = shift;
	
	my $plugins = $self->plugins;
	return if not $plugins->{$name} or not $plugins->{$name}->{object};
	foreach my $editor ( $self->parent->wx->main_window->pages ) {
		if ( $plugins->{$name}->{object}->can('editor_enable') ) {
			$plugins->{$name}->{object}->editor_enable( $editor, $editor->{Document} );
		}
	}
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


# recreate the Plugins menu
sub _refresh_plugin_menu {
	my $self = shift;
	my $main = $self->parent->wx->main_window;

	# Regenerate the menu
	my $menu    = $main->{menu};
	my $submenu = $menu->menu_plugin($main);
	my $place   = $menu->{wx}->FindMenu( Wx::gettext("Pl&ugins") );

	# Update the menu
	$menu->{wx}->Replace( $place, $submenu, Wx::gettext("Pl&ugins") );
	$menu->refresh;
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
		$plugins->{$_}->{status} eq 'failed'
	} keys %$plugins;
}

# TODO: document this.
sub test_a_plugin {
	my $self    = shift;
        my $main    = $self->parent->wx->main_window;
	my $config  = $self->parent->config;
	my $plugins = $self->plugins;

	my $last_filename = $config->{last_test_plugin_file};
	$last_filename  ||= $main->selected_filename;
	my $default_dir;
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
	if ( $self->plugins->{$filename}->{status} eq 'failed' ) {
		$main->error("Faild to load the plugin '$filename'");
		return;
	}

	$self->reload_plugins;
}

sub get_menu {
	my $self    = shift;
	my $main    = shift;
	my $name    = shift;
	my $plugin  = $self->plugins->{$name};
	unless ( $plugin and $plugin->{status} eq 'loaded' ) {
		return ();
	}
	unless ( $plugin->{object}->can('menu_plugins') ) {
		return ();
	}
	my ($label, $menu) = eval { $plugin->{object}->menu_plugins($main) };
	if ( $@ ) {
		$self->{errstr} = "Error when calling menu for plugin '$name' $@";
		return ();
	}
	return ($label, $menu);
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

