package Padre::Action::Plugins;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Constant ();
use Padre::Config   ();
use Padre::Wx       ();
use Padre::Action   ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.50';





#####################################################################
# Padre::Action::Plugins Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Link to the Plugin Manager
	Padre::Action->new(
		name       => 'plugins.plugin_manager',
		label      => Wx::gettext('Plugin Manager'),
		comment    => Wx::gettext('Show the Padre plugin manager to enable or disable plugins'),
		menu_event => sub {
			require Padre::Wx::Dialog::PluginManager;
			Padre::Wx::Dialog::PluginManager->new(
				$_[0],
				Padre->ide->plugin_manager,
			)->show;
		},
	);

	# TODO: should be replaced by a link to http://cpan.uwinnipeg.ca/chapter/World_Wide_Web_HTML_HTTP_CGI/Padre
	# better yet, by a window that also allows the installation of all the plugins that can take into account
	# the type of installation we have (ppm, stand alone, rpm, deb, CPAN, etc.)
	Padre::Action->new(
		name       => 'plugins.plugin_list',
		label      => Wx::gettext('Plugin List (CPAN)'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://cpan.uwinnipeg.ca/search?query=Padre%3A%3APlugin%3A%3A&mode=dist');
		},
	);

	Padre::Action->new(
		name       => 'plugins.edit_my_plugin',
		label      => Wx::gettext('Edit My Plugin'),
		comment    => Wx::gettext('My-Plugin is a plugin where developers could extend their Padre installation'),
		menu_event => sub {
			my $file = File::Spec->catfile(
				Padre::Constant::CONFIG_DIR,
				qw{ plugins Padre Plugin My.pm }
			);
			return $self->error( Wx::gettext("Could not find the Padre::Plugin::My plugin") ) unless -e $file;

			# Use the plural so we get the "close single unused document"
			# behaviour, and so we get a free freezing and refresh calls.
			$_[0]->setup_editors($file);
		},
	);

	Padre::Action->new(
		name       => 'plugins.reload_my_plugin',
		label      => Wx::gettext('Reload My Plugin'),
		comment    => Wx::gettext('This function reloads the My-Plugin without restarting Padre'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_plugin('Padre::Plugin::My');
		},
	);

	Padre::Action->new(
		name       => 'plugins.reset_my_plugin',
		label      => Wx::gettext('Reset My Plugin'),
		comment    => Wx::gettext('Reset the My-Plugin to the default'),
		menu_event => sub {
			my $ret = Wx::MessageBox(
				Wx::gettext("Reset My Plugin"),
				Wx::gettext("Reset My Plugin"),
				Wx::wxOK | Wx::wxCANCEL | Wx::wxCENTRE,
				$main,
			);
			if ( $ret == Wx::wxOK ) {
				my $manager = Padre->ide->plugin_manager;
				$manager->unload_plugin('Padre::Plugin::My');
				$manager->reset_my_plugin(1);
				$manager->load_plugin('Padre::Plugin::My');
			}
		},
	);

	Padre::Action->new(
		name       => 'plugins.reload_all_plugins',
		label      => Wx::gettext('Reload All Plugins'),
		comment    => Wx::gettext('Reload all plugins from disk'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_plugins;
		},
	);

	Padre::Action->new(
		name       => 'plugins.reload_current_plugin',
		label      => Wx::gettext('(Re)load Current Plugin'),
		comment    => Wx::gettext('Reloads (or initially loads) the current plugin'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_current_plugin;
		},
	);

	#	Padre::Action->new(
	#		$tools,
	#		name       => 'plugins.test_a_plugin',
	#		label      => Wx::gettext('Test A Plugin From Local Dir'),
	#		menu_event => sub {
	#			Padre->ide->plugin_manager->test_a_plugin;
	#		},
	#	);


	Padre::Action->new(
		name       => 'plugins.install_cpan',
		label      => Wx::gettext("Install CPAN Module"),
		comment    => Wx::gettext('Install a Perl module from CPAN'),
		menu_event => sub {
			require Padre::CPAN;
			require Padre::Wx::CPAN;
			my $cpan = Padre::CPAN->new;
			my $gui = Padre::Wx::CPAN->new( $cpan, $_[0] );
			$gui->show;
		}
	);

	Padre::Action->new(
		name       => 'plugins.install_local',
		label      => Wx::gettext("Install Local Distribution"),
		menu_event => sub {
			$self->install_file( $_[0] );
		},
	);

	Padre::Action->new(
		name       => 'plugins.install_remote',
		label      => Wx::gettext("Install Remote Distribution"),
		menu_event => sub {
			$self->install_url( $_[0] );
		},
	);

	Padre::Action->new(
		name       => 'plugins.cpan_config',
		label      => Wx::gettext("Open CPAN Config File"),
		menu_event => sub {
			$self->cpan_config( $_[0] );
		},
	);

	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
