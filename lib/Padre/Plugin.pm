package Padre::Plugin;

=pod

=head1 NAME

Padre::Plugin - Padre Plugin API 2.2

=head1 SYNOPSIS

  package Padre::Plugin::Foo;
  
  use strict;
  use base 'Padre::Plugin';
  
  # The plugin name to show in the Plugin Manager and menus
  sub plugin_name {
      'Example Plugin';
  }
  
  # Declare the Padre interfaces this plugin uses
  sub padre_interfaces {
      'Padre::Plugin'         => 0.29,
      'Padre::Document::Perl' => 0.29,
      'Padre::Wx::Main'       => 0.29,
      'Padre::DB'             => 0.29,
  }
  
  # The command structure to show in the Plugins menu
  sub menu_plugins_simple {
      my $self = shift;
      return $self->plugin_name => [
          'About'   => sub { $self->show_about },
          'Submenu' => [
              'Do Something' => sub { $self->do_something },
          ],
      ];
  }
  
  1;

=cut

use 5.008;
use strict;
use warnings;
use Carp           ();
use File::Spec     ();
use File::ShareDir ();
use Scalar::Util   ();
use Params::Util   ();
use YAML::Tiny     ();
use Padre::DB      ();
use Padre::Wx      ();

our $VERSION    = '0.46';
our $COMPATIBLE = '0.43';

# Link plugins back to their IDE
my %IDE = ();





######################################################################
# Static Methods

=pod

=head1 STATIC/CLASS METHODS

=head2 plugin_name

The C<plugin_name> method will be called by Padre when it needs a name
to display in the user inferface.

The default implementation will generate a name based on the class name
of the plugin.

=cut

sub plugin_name {
	my $class = ref $_[0] || $_[0];
	my @words = $class =~ /(\w+)/gi;
	my $name = pop @words;
	$name =~ s/([a-z])([A-Z])/$1 $2/g;
	$name =~ s/([A-Z]+)([A-Z][a-z]+)/$1 $2/g;
	return $name;
}

=pod

=head2 plugin_directory_share

The C<plugin_directory_share> method finds the location of the shared
files directory for the plugin, if one exists.

Returns a path string if the share directory exists, or C<undef> if not.

=cut

sub plugin_directory_share {
	my $class = shift;
	$class =~ s/::/-/g;
	$class =~ s/\=HASH\(.+?\)$//;

	if ( $ENV{PADRE_DEV} ) {
		my $root = File::Spec->catdir(
			$FindBin::Bin,
			File::Spec->updir,
			File::Spec->updir,
			$class,
		);
		my $path = File::Spec->catdir( $root, 'share' );
		return $path if -d $path;
		$path = File::Spec->catdir(
			$root,
			'lib',
			split( /-/, $class ),
			'share',
		);
		return $path if -d $path;
		return;
	}

	# Find the distribution directory
	my $dist = eval { File::ShareDir::dist_dir($class) };
	return $@ ? undef : $dist;
}

=pod

=head2 plugin_directory_locale

The C<plugin_directory_locale()> method will be called by Padre to
know where to look for your plugin l10n catalog.

It defaults to C<$sharedir/locale> (with C<$sharedir> as defined by
C<File::ShareDir> and thus should work as is for your plugin if you're
using the C<install_share> command of C<Module::Install>.

Your plugin catalogs should be named C<$plugin-$locale.po> (or C<.mo>
for the compiled form) where $plugin is the class name of your plugin with
any character that are illegal in file names (on all file systems)
flattened to underscores.

That is, C<Padre__Plugin__Vi-de.po> for the german locale of
C<Padre::Plugin::Vi>.

=cut

sub plugin_directory_locale {
	my $class = shift;
	my $share = $class->plugin_directory_share or return;
	return File::Spec->catdir( $share, 'locale' );
}

# NOTE Back-compatibility
sub plugin_locale_directory {
	shift->plugin_directory_locale(@_);
}

=pod

=head2 plugin_icon

The C<plugin_icon> method will be called by Padre when it needs an
icon to display in the user interface. It should return a 16x16
C<Wx::Bitmap> object.

The default implementation will look for an icon at the path
F<$plugin_directory_share/icons/16x16/logo.png> and load it for you.

=cut

sub plugin_icon {
	my $class = shift;
	my $share = $class->plugin_directory_share or return;
	my $file  = File::Spec->catfile( $share, 'icons', '16x16', 'logo.png' );
	return undef unless -f $file;
	return undef unless -r $file;
	return Wx::Bitmap->new( $file, Wx::wxBITMAP_TYPE_PNG );
}

=pod

=head2 padre_interfaces

  sub padre_interfaces {
      'Padre::Plugin'         => 0.43,
      'Padre::Document::Perl' => 0.35,
      'Padre::Wx::Main'       => 0.43,
      'Padre::DB'             => 0.25,
  }

In Padre, plugins are permitted to make relatively deep calls into
Padre's internals. This allows a lot of freedom, but comes at the cost
of allowing plugins to damage or crash the editor.

To help compensate for any potential problems, the Plugin Manager expects each
Plugin module to define the Padre classes that the Plugin uses, and the version
of Padre that the code was originally written against (for each class).

This information will be used by the plugin manager to calculate whether or
not the Plugin is still compatible with Padre.

The list of interfaces should be provided as a list of class/version
pairs, as shown in the example.

The padre_interfaces method will be called on the class, not on the plugin
object. By default, this method returns nothing.

In future, plugins that do NOT supply compatibility information may be
disabled unless the user has specifically allowed experimental plugins.

=cut

sub padre_interfaces {
	return ();
}





######################################################################
# Default Constructor

=pod

=head1 CONSTRUCTORS

=head2 new

The new constructor takes no parameters. When a plugin is loaded,
Padre will instantiate one plugin object for each plugin, to provide
the plugin with a location to store any private or working data.

A default constructor is provided that creates an empty HASH-based
object.

=cut

sub new {
	my $class = shift;
	my $ide   = shift;
	unless ( Params::Util::_INSTANCE( $ide, 'Padre' ) ) {
		Carp::croak("Did not provide a Padre ide object");
	}

	# Create the basic object
	my $self = bless {}, $class;

	# Store the link back to the IDE
	$IDE{ Scalar::Util::refaddr($self) } = $ide;

	return $self;
}

sub DESTROY {
	delete $IDE{ Scalar::Util::refaddr( $_[0] ) };
}





#####################################################################
# Instance Methods

=pod

=head1 INSTANCE METHODS

=head2 registered_documents

  sub registered_documents {
      'application/javascript' => 'Padre::Plugin::JavaScript::Document',
      'application/json'       => 'Padre::Plugin::JavaScript::Document',
  }

The C<registered_documents> methods can be used by a plugin to define
document types for which the plugin provides a document class
(which is used by Padre to enable functionality beyond the level of
a plain text file with simple Scintilla highlighting).

This method will be called by the Plugin Manager and the information returned
will be used to populate various internal data and do various other tasks at
a time of its choosing. Plugin authors are expected to provide this
information without having to know how or why Padre will use it.

This (theoretically at this point) should allow Padre to keep a document open
while a plugin is being enabled or disabled, upgrading or downgrading the
document in the process.

The method call is made on the Plugin object, and returns a list of
MIME-type to class pairs. By default the method returns a null list, 
which indicates that the plugin does not provide any document types.

=cut

sub registered_documents {
	return ();
}

=head2 provided_highlighters

Default method returning an empty array.

TBD. See Padre::Document

=cut

sub provided_highlighters {
	return ();
}

=head2 highlighting_mime_types

TBD. See Padre::Document

=cut

sub highlighting_mime_types {
	return ();
}

=pod

=head2 event_on_context_menu

If implemented in a plugin, this method will be called when a
context menu is about to be displayed either because the user
pressed the right mouse button in the editor window (C<Wx::MouseEvent>)
or because the C<Right-click> menu entry was selected in the C<Window>
menu (C<Wx::CommandEvent>). The context menu object was created
and populated by the Editor and then possibly augmented by the
C<Padre::Document> type (see L<Padre::Document/event_on_right_down>).

Parameters retrieved are the objects for the document, the editor, the 
context menu (C<Wx::Menu>) and the event.

Have a look at the implementation in L<Padre::Document::Perl> for
an example.

=head2 plugin_enable

The C<plugin_enable> object method will be called (at an arbitrary time of Padre's
choosing) to allow the plugin object to initialise and start up the Plugin.

This may involve loading any config files, hooking into existing documents or
editor windows, and otherwise doing anything needed to bootstrap operations.

Please note that Padre will block until this method returns, so you should
attempt to complete return as quickly as possible.

Any modules that you may use should NOT be loaded during this phase, but should
be C<require>ed when they are needed, at the last moment.

Returns true if the plugin started up ok, or false on failure.

The default implementation does nothing, and returns true.

=cut

sub plugin_enable {
	return 1;
}

=pod

=head2 plugin_disable

The C<plugin_disable> method is called by Padre for various reasons to request
the plugin do whatever tasks are necesary to shut itself down. This also
provides an opportunity to save configuration information, save caches to
disk, and so on.

Most often, this will be when Padre itself is shutting down. Other uses may
be when the user wishes to disable the plugin, when the plugin is being
reloaded, or if the plugin is about to be upgraded.

If you have any private classes other than the standard Padre::Plugin::Foo, you
should unload them as well as the plugin may be in the process of upgrading
and will want those classes freed up for use by the new version.

The recommended way of unloading your extra classes is using
L<Class::Unload>. Suppose you have C<My::Extra::Class> and want to unload it,
simply do this in C<plugin_disable>:

  require Class::Unload;
  Class::Unload->unload('My::Extra::Class');

Class::Unload takes care of all the tedious bits for you. Note that you
should B<not> unload any external CPAN dependencies, as these may be needed
by other plugins or Padre itself. Only classes that are part of your plugin
should be unloaded.

Returns true on success, or false if the unloading process failed and your
plugin has been left in an unknown state.

=cut

sub plugin_disable {
	return 1;
}

=pod

=head2 config_read

  my $hash = $self->config_read;
  if ( $hash ) {
      print "Loaded existing configuration\n";
  } else {
      print "No existing configuration";
  }

The C<config_read> method provides access to host-specific configuration
stored in a persistant location by Padre.

At this time, the configuration must be a nested, non-cyclic structure of
C<HASH> references, C<ARRAY> references and simple scalars (the use of
C<undef> values is permitted) with a C<HASH> reference at the root.

Returns a nested C<HASH>-root structure if there is an existing saved
configuration for the plugin, or C<undef> if there is no existing saved
configuration for the plugin.

=cut

sub config_read {
	my $self = shift;

	# Retrieve the config string from the database
	my $class = Scalar::Util::blessed($self);
	my @row   = Padre::DB->selectrow_array(
		'select config from plugin where name = ?', {},
		$class,
	);
	return undef unless defined $row[0];

	# Parse the config from the string
	my @config = YAML::Tiny::Load( $row[0] );
	unless ( Params::Util::_HASH0( $config[0] ) ) {
		Carp::croak('Config for plugin was not a HASH refence');
	}

	return $config[0];
}

=pod

=head2 config_write

  $self->config_write( { foo => 'bar' } );

The C<config_write> method is used to write the host-specific configuration
information for the plugin into the underlying database storage.

At this time, the configuration must be a nested, non-cyclic structure of
C<HASH> references, C<ARRAY> references and simple scalars (the use of
C<undef> values is permitted) with a C<HASH> reference at the root.

=cut

sub config_write {
	my $self   = shift;
	my $config = shift;
	unless ( Params::Util::_HASH0($config) ) {
		Carp::croak('Did not provide a HASH ref to config_write');
	}

	# Convert the config to a string
	my $string = YAML::Tiny::Dump($config);

	# Write the config string to the database
	my $class = Scalar::Util::blessed($self);
	Padre::DB->do(
		'update plugin set config = ? where name = ?', {},
		$string, $class,
	);

	return 1;
}

=pod

=head2 plugin_preferences

  $plugin->plugin_preferences($wx_parent);

The C<plugin_preferences> method allows a plugin to define an entry point
for the Plugin Manager dialog to trigger to show a preferences or
configuration dialog for the plugin.

The method is passed a wx object that should be used as the wx parent.

=cut

# This method is only implemented in the plugin children

=pod

=head2 menu_plugins_simple

  sub menu_plugins_simple {
      'My Plugin' => [
          Submenu  => [
              'Do Something' => sub { $self->do_something },
          ],
          '---' => undef,        # Separator
          About => 'show_about', # Shorthand for sub { $self->show_about(@_) }
          "Action\tCtrl+Shift+Z" => 'action', # Also use keyboard shortcuts 
					      # to call sub { $self->show_about(@_) }
      ];
  }

The C<menu_plugins_simple> method defines a simple menu structure for your
plugin.

It returns two values, the label for the menu entry to be used in the top
level Plugins menu, and a reference to an ARRAY containing an B<ordered> set of
key/value pairs that will be turned into menus.

If the key is a string containing three hyphons (i.e. '---') the pair will be
rendered as a menu seperator.

If the key is a string containing a tab ("\t") and a keyboard shorcut combination
the menu action will also be available through a keyboard shortcut.

If the value is a Perl identifier, it will be treated as a method name to be
called on the plugin object when the menu entry is triggered.

If the value is a reference to an ARRAY, the pair will be rendered as a
sub-menu containing further menu items.

=cut

sub menu_plugins_simple {

	# Plugins returning no data will not
	# be visible in the plugin menu.
	return ();
}

=pod

=head2 menu_plugins

  sub menu_plugins {
      my $self        = shift;
      my $main = shift;
  
      # Create a simple menu with a single About entry
      my $menu = Wx::Menu->new;
      Wx::Event::EVT_MENU(
          $main,
          $menu->Append( -1, 'About', ),
          sub { $self->show_about },
      );
  
      # Return it and the label for our plugin
      return ( $self->plugin_name => $menu );

The C<menu_plugins> method defines a fully-featured mechanism for building
your plugin menu.

It returns two values, the label for the menu entry to be used in the top level
Plugins menu, and a L<Wx::Menu> object containing the custom-built menu structure.

A default implementation of this method is provided which will call
C<menu_plugins_simple> and implements the expansion of the simple data into a full
menu structure.

If the method return a null list, no menu entry will be created for the plugin.

=cut

sub menu_plugins {
	my $self   = shift;
	my $main   = shift;
	my @simple = $self->menu_plugins_simple or return ();
	my $label  = $simple[0];
	my $menu   = $self->_menu_plugins_submenu( $main, $simple[1] ) or return ();
	return ( $label, $menu );
}

sub _menu_plugins_submenu {
	my $self  = shift;
	my $main  = shift;
	my $items = shift;
	unless ( $items and ref $items and ref $items eq 'ARRAY' and not @$items % 2 ) {
		return;
	}

	# Fill the menu
	my $menu = Wx::Menu->new;
	while (@$items) {
		my $label = shift @$items;
		my $value = shift @$items;

		# Separator
		unless ( defined $value ) {
			if ( $label eq '---' ) {
				$menu->AppendSeparator;
				next;
			}
			Carp::cluck("Undefined value for label '$label'");
		}

		# Method Name
		if ( Params::Util::_IDENTIFIER($value) ) {

			# Convert to a function reference
			my $method = $value;
			$value = sub { $self->$method(@_) };
		}

		# Function Reference
		if ( Params::Util::_CODE($value) ) {
			Wx::Event::EVT_MENU(
				$main,
				$menu->Append( -1, $label ),
				sub {
					eval { $value->(@_) };
					Carp::cluck($@) if $@;
				},
			);
			next;
		}

		# Array Reference (submenu)
		if ( Params::Util::_ARRAY0($value) ) {
			my $submenu = $self->_menu_plugins_submenu( $main, $value );
			$menu->Append( -1, $label, $submenu );
			next;
		}

		Carp::cluck("Unknown or invalid menu entry (label '$label' and value '$value')");
	}

	return $menu;
}





######################################################################
# Event Handlers

=pod

=head2 editor_enable

  sub editor_enable {
      my $self     = shift;
      my $editor   = shift;
      my $document = shift;
  
      # Make changes to the editor here...
  
      return 1;
  }

The C<editor_enable> method is called by Padre to provide the plugin with
an opportunity to alter the setup of the editor as it is being loaded.

This method is only triggered when new editor windows are opened. Hooking
into any existing open documents must be done within the C<plugin_enable>
method.

The method is passed two parameters, the fully set up editor object, and
the L<Padre::Document> being opened.

At the present time, this method has been provided primarily for the use
of the L<Padre::Plugin::Vi> plugin and other plugins that need
deep integration with the editor widget.

=cut

sub editor_enable {
	return 1;
}

=pod

=head2 editor_disable

  sub editor_disable {
      my $self     = shift;
      my $editor   = shift;
      my $document = shift;
  
      # Undo your changes to the editor here...
  
  return 1;

The C<editor_disable> method is the twin of the previous C<editor_enable>
method. It is called as the file in the editor is being closed, AFTER the
used has confirmed the file is to be closed.

It provides the plugin with an opportunity to clean up, remove any gui
customisations, and complete any other shutdown/close processes.

The method is passed two parameters, the fully set up editor object, and
the L<Padre::Document> being closed.

At the present time, this method has been provided primarily for the use
of the L<Padre::Plugin::Vi> plugin and other plugins that need 
deep integration with the editor widget.

=cut

sub editor_disable {
	return 1;
}





#####################################################################
# Padre Integration Methods

=pod

=head2 ide

The C<ide> convenience method provides access to the root-level L<Padre>
IDE object, preventing the need to go via the global Padre-E<gt>ide
method.

=cut

sub ide {
	$IDE{ Scalar::Util::refaddr( $_[0] ) };
}

=pod

=head2 main

The C<main> convenience method provides direct access to the
L<Padre::Wx::Main> (main window) object.

=cut

sub main {
	$IDE{ Scalar::Util::refaddr( $_[0] ) }->wx->main;
}

=pod

=head2 current

The C<current> convenience method provides a L<Padre::Current> context
object for the current plugin.

=cut

sub current {
	Padre::Current->new( ide => $_[0]->ide );
}

1;

=pod

=head1 SEE ALSO

L<Padre>

=head1 COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
