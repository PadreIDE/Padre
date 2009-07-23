package Padre::Wx::Menu::Plugins;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Constant ();
use Padre::Current qw{_CURRENT};
use Padre::Config   ();
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.41';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Link to the Plugin Manager
	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext("Plugin Manager") ),
		sub {
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
	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext("Plugin List (CPAN)") ),
		sub {
			Padre::Wx::launch_browser('http://cpan.uwinnipeg.ca/search?query=Padre%3A%3APlugin%3A%3A&mode=dist');
		},
	);

	# Create the plugin tools submenu
	my $tools = Wx::Menu->new;
	Wx::Event::EVT_MENU(
		$main,
		$tools->Append( -1, Wx::gettext("Edit My Plugin") ),
		sub {
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

	Wx::Event::EVT_MENU(
		$main,
		$tools->Append( -1, Wx::gettext("Reload My Plugin") ),
		sub {
			Padre->ide->plugin_manager->reload_plugin('My');
		},
	);

	Wx::Event::EVT_MENU(
		$main,
		$tools->Append( -1, Wx::gettext("Reset My Plugin") ),
		sub {
			my $ret = Wx::MessageBox(
				Wx::gettext("Reset My Plugin"),
				Wx::gettext("Reset My Plugin"),
				Wx::wxOK | Wx::wxCANCEL | Wx::wxCENTRE,
				$main,
			);
			if ( $ret == Wx::wxOK ) {
				my $manager = Padre->ide->plugin_manager;
				$manager->unload_plugin("My");
				$manager->reset_my_plugin(1);
				$manager->load_plugin("My");
			}
		},
	);

	$tools->AppendSeparator;

	Wx::Event::EVT_MENU(
		$main,
		$tools->Append( -1, Wx::gettext("Reload All Plugins") ),
		sub {
			Padre->ide->plugin_manager->reload_plugins;
		},
	);

	Wx::Event::EVT_MENU(
		$main,
		$tools->Append( -1, Wx::gettext("(Re)load Current Plugin") ),
		sub {
			Padre->ide->plugin_manager->reload_current_plugin;
		},
	);

	Wx::Event::EVT_MENU(
		$main,
		$tools->Append( -1, Wx::gettext("Test A Plugin From Local Dir") ),
		sub {
			Padre->ide->plugin_manager->test_a_plugin;
		},
	);

	# Add the tools submenu
	$self->Append( -1, Wx::gettext('Plugin Tools'), $tools );

	$self->add_plugin_specific_entries($main);

	return $self;
}

sub add_plugin_specific_entries {
	my $self = shift;
	my $main = shift;

	# Clear out any existing entries
	my $manager = Padre->ide->plugin_manager;
	my $entries = $self->{plugin_menus} || [];
	$self->remove_plugin_specific_entries if @$entries;

	# Add the enabled plugins that want a menu
	my $need_seperator = 1;
	foreach my $name ( $manager->plugin_names ) {
		my $plugin = $manager->_plugin($name);
		next unless $plugin->enabled;

		# Generate the menu for the plugin
		my @menu = $manager->get_menu( $main, $name );
		next unless @menu;

		# Did the previous entry needs a separator after it
		if ($need_seperator) {
			push @$entries, $self->AppendSeparator;
			$need_seperator = 0;
		}

		push @$entries, $self->Append( -1, @menu );
		if ( $name eq 'My' ) {
			$need_seperator = 1;
		}
	}

	$self->{plugin_menus} = $entries;

	return 1;
}

sub remove_plugin_specific_entries {
	my $self = shift;
	my $entries = $self->{plugin_menus} || [];

	while (@$entries) {
		$self->Destroy( pop @$entries );
	}
	$self->{plugin_menus} = $entries;

	return 1;
}

sub refresh {
	my $self = shift;
	my $main = _CURRENT(@_)->main;

	$self->remove_plugin_specific_entries;
	$self->add_plugin_specific_entries($main);

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
