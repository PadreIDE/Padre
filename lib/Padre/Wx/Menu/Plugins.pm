package Padre::Wx::Menu::Plugins;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Constant ();
use Padre::Config   ();
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.43';
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
	$self->add_menu_item(
		$self,
		name       => 'plugins.plugin_manager',
		label      => Wx::gettext('Plugin Manager'),
		menu_event => sub {
			require Padre::Wx::Dialog::PluginManager;
			Padre::Wx::Dialog::PluginManager->new(
				$_[0],
				Padre->ide->plugin_manager,
			)->show;
		},
	);

	# Create the plugin tools submenu
	my $tools = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Plugin Tools'),
		$tools,
	);

	# TODO: should be replaced by a link to http://cpan.uwinnipeg.ca/chapter/World_Wide_Web_HTML_HTTP_CGI/Padre
	# better yet, by a window that also allows the installation of all the plugins that can take into account
	# the type of installation we have (ppm, stand alone, rpm, deb, CPAN, etc.)
	$self->add_menu_item(
		$tools,
		name       => 'plugins.plugin_list',
		label      => Wx::gettext('Plugin List (CPAN)'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://cpan.uwinnipeg.ca/search?query=Padre%3A%3APlugin%3A%3A&mode=dist');
		},
	);

	$tools->AppendSeparator;

	$self->add_menu_item(
		$tools,
		name       => 'plugins.edit_my_plugin',
		label      => Wx::gettext('Edit My Plugin'),
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

	$self->add_menu_item(
		$tools,
		name       => 'plugins.reload_my_plugin',
		label      => Wx::gettext('Reload My Plugin'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_plugin('Padre::Plugin::My');
		},
	);

	$self->add_menu_item(
		$tools,
		name       => 'plugins.reset_my_plugin',
		label      => Wx::gettext('Reset My Plugin'),
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

	$tools->AppendSeparator;

	$self->add_menu_item(
		$tools,
		name       => 'plugins.reload_all_plugins',
		label      => Wx::gettext('Reload All Plugins'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_plugins;
		},
	);

	$self->add_menu_item(
		$tools,
		name       => 'plugins.reload_current_plugin',
		label      => Wx::gettext('(Re)load Current Plugin'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_current_plugin;
		},
	);

	$self->add_menu_item(
		$tools,
		name       => 'plugins.test_a_plugin',
		label      => Wx::gettext('Test A Plugin From Local Dir'),
		menu_event => sub {
			Padre->ide->plugin_manager->test_a_plugin;
		},
	);

	# Create the module tools submenu
	my $modules = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Module Tools'),
		$modules,
	);

	Wx::Event::EVT_MENU(
		$main,
		$modules->Append(
			-1,
			Wx::gettext("Install CPAN Module"),
		),
		sub {
			require Padre::CPAN;
			require Padre::Wx::CPAN;
			my $cpan = Padre::CPAN->new;
			my $gui = Padre::Wx::CPAN->new( $cpan, $_[0] );
			$gui->show;
		}
	);

	Wx::Event::EVT_MENU(
		$main,
		$modules->Append(
			-1,
			Wx::gettext("Install Local Distribution"),
		),
		sub {
			$self->install_file( $_[0] );
		},
	);

	Wx::Event::EVT_MENU(
		$main,
		$modules->Append(
			-1,
			Wx::gettext("Install Remote Distribution"),
		),
		sub {
			$self->install_url( $_[0] );
		},
	);

	$modules->AppendSeparator;

	Wx::Event::EVT_MENU(
		$main,
		$modules->Append(
			-1,
			Wx::gettext("Open CPAN Config File"),
		),
		sub {
			$self->cpan_config( $_[0] );
		},
	);

	$self->add($main);

	return $self;
}

sub add {
	my $self = shift;
	my $main = shift;

	# Clear out any existing entries
	my $entries = $self->{plugin_menus} || [];
	$self->remove if @$entries;

	# Add the enabled plugins that want a menu
	my $need    = 1;
	my $manager = Padre->ide->plugin_manager;
	foreach my $module ( $manager->plugin_order ) {
		my $plugin = $manager->_plugin($module);
		next unless $plugin->enabled;

		# Generate the menu for the plugin
		my @menu = $manager->get_menu( $main, $module ) or next;

		# Did the previous entry needs a separator after it
		if ($need) {
			push @$entries, $self->AppendSeparator;
			$need = 0;
		}

		push @$entries, $self->Append( -1, @menu );
		if ( $module eq 'Padre::Plugin::My' ) {
			$need = 1;
		}
	}

	$self->{plugin_menus} = $entries;

	return 1;
}

sub remove {
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

	$self->remove;
	$self->add($main);

	return 1;
}





#####################################################################
# Module Tools

sub install_file {
	my $self = shift;
	my $main = shift;

	# Ask what we should install
	my $dialog = Wx::FileDialog->new(
		$main,
		Wx::gettext("Select distribution to install"),
		'',                                  # Default directory
		'',                                  # Default file
		'CPAN Packages (*.tar.gz)|*.tar.gz', # wildcard
		Wx::wxFD_OPEN | Wx::wxFD_FILE_MUST_EXIST
	);
	$dialog->CentreOnParent;
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetPath;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error( Wx::gettext("Did not provide a distribution") );
		return;
	}

	$self->install_pip( $main, $string );
	return;
}

sub install_url {
	my $self = shift;
	my $main = shift;

	# Ask what we should install
	my $dialog = Wx::TextEntryDialog->new(
		$main,
		Wx::gettext("Enter URL to install\ne.g. http://svn.ali.as/cpan/releases/Config-Tiny-2.00.tar.gz"),
		"pip",
		'',
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error( Wx::gettext("Did not provide a distribution") );
		return;
	}

	$self->install_pip( $main, $string );
	return;
}

sub install_pip {
	my $self   = shift;
	my $main   = shift;
	my $module = shift;

	# Find 'pip', used to install modules
	require File::Which;
	my $pip = scalar File::Which::which('pip');
	unless ( -f $pip ) {
		$main->error( Wx::gettext("pip is unexpectedly not installed") );
		return;
	}

	$main->setup_bindings;

	# Run with the same Perl that launched Padre
	my $perl = Padre::Perl::perl();
	my $cmd  = qq{"$perl" "$pip" "$module"};
	local $ENV{AUTOMATED_TESTING} = 1;
	Wx::Perl::ProcessStream->OpenProcess( $cmd, 'CPAN_mod', $main );

	return;
}

sub cpan_config {
	my $self = shift;
	my $main = shift;

	# Locate the CPAN config file(s)
	my $default_dir = '';
	eval {
		require CPAN;
		$default_dir = $INC{'CPAN.pm'};
		$default_dir =~ s/\.pm$//is; # remove .pm
	};

	# Load the main config first
	if ( $default_dir ne '' ) {
		my $core = File::Spec->catfile( $default_dir, 'Config.pm' );
		if ( -e $core ) {
			$main->setup_editors($core);
			return;
		}
	}

	# Fallback to a personal config
	my $user = File::Spec->catfile(
		File::HomeDir->my_home,
		'.cpan', 'CPAN', 'MyConfig.pm'
	);
	if ( -e $user ) {
		$main->setup_editors($user);
		return;
	}

	$main->error( Wx::gettext("Failed to find your CPAN configuration") );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
