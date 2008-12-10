package Padre::Wx::Menu::Plugins;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Params::Util       ();
use Padre::Wx          ();
use Padre::Wx::Submenu ();

our $VERSION = '0.20';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Link to the Plugin Manager
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Plugin Manager") ),
		sub {
			Padre::Wx::Dialog::PluginManager->show(@_);
		},
	);

	# Create the plugin tools submenu
	my $tools = Wx::Menu->new;
	Wx::Event::EVT_MENU( $main,
		$tools->Append( -1, Wx::gettext("Edit My Plugin") ),
		sub {
			my $file = File::Spec->catfile(
				Padre->ide->config_dir,
				qw{ plugins Padre Plugin My.pm }
			);
			return $self->error(
				Wx::gettext("Could not find the Padre::Plugin::My plugin")
			) unless -e $file;
			$_[0]->setup_editor($file);
			$_[0]->refresh;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$tools->Append( -1, Wx::gettext("Reload My Plugin") ),
		sub {
			Padre->ide->plugin_manager->reload_plugin('My');
		},
	);
	Wx::Event::EVT_MENU( $main,
		$tools->Append( -1, Wx::gettext("Reset My Plugin") ),
		sub  {
			my $ret = Wx::MessageBox(
				Wx::gettext("Reset My Plugin"),
				Wx::gettext("Reset My Plugin"),
				Wx::wxOK | Wx::wxCANCEL | Wx::wxCENTRE,
				$main,
			);
			if ( $ret == Wx::wxOK) {
				my $manager = Padre->ide->plugin_manager;
				my $target = File::Spec->catfile(
					$manager->plugin_dir,
					qw{ Padre Plugin My.pm }
				);
				$manager->unload_plugin("My");
				Padre::Config->copy_original_My_plugin($target);
				$manager->load_plugin("My");
			}
		},
	);
	$tools->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$tools->Append( -1, Wx::gettext("Reload All Plugins") ),
		sub {
			Padre->ide->plugin_manager->reload_plugins;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$tools->Append( -1, Wx::gettext("Test A Plugin From Local Dir") ),
		sub {
			Padre->ide->plugin_manager->test_a_plugin;
		},
	);

	# Add the tools submenu
	$self->Append( -1, Wx::gettext('Plugin Tools'), $tools );

	# Get the list of plugins
	my $manager = Padre->ide->plugin_manager;
	my $plugins = $manager->plugins;
	my @plugins = grep { $_ ne 'My' } sort keys %$plugins;

	# Add the enabled plugins that want a menu
	my $need_seperator = 1;
	foreach my $name ( 'My', @plugins ) {
		next unless $plugins->{$name};
		next unless $plugins->{$name}->{status};
		next unless $plugins->{$name}->{status} eq 'loaded';

		my @menu = $manager->get_menu( $main, $name );
		next unless @menu;

		if ( $need_seperator ) {
			$self->AppendSeparator;
			$need_seperator = 0;
		}

		$self->Append( -1, @menu );
		if ( $name eq 'My' ) {
			$need_seperator = 1;
		}
	}

	return $self;
}

1;
