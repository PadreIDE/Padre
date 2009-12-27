package Padre::Action::Plugins;

use 5.008;
use strict;
use warnings;

use Padre::Action   ();
use Padre::Constant ();
use Padre::Config   ();
use Padre::Current qw{_CURRENT};
use Padre::Util    ('_T');
use Padre::Wx       ();

our $VERSION = '0.53';


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
		label      => _T('Plug-in Manager'),
		comment    => _T('Show the Padre plug-in manager to enable or disable plug-ins'),
		menu_event => sub {
			require Padre::Wx::Dialog::PluginManager;
			Padre::Wx::Dialog::PluginManager->new(
				$_[0],
				Padre->ide->plugin_manager,
			)->show;
		},
	);

	# TO DO: should be replaced by a link to http://cpan.uwinnipeg.ca/chapter/World_Wide_Web_HTML_HTTP_CGI/Padre
	# better yet, by a window that also allows the installation of all the plug-ins that can take into account
	# the type of installation we have (ppm, stand alone, rpm, deb, CPAN, etc.)
	Padre::Action->new(
		name       => 'plugins.plugin_list',
		label      => _T('Plug-in List (CPAN)'),
		comment    => _T('Open browser to a CPAN search showing the Padre::Plugin packages'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://cpan.uwinnipeg.ca/search?query=Padre%3A%3APlugin%3A%3A&mode=dist');
		},
	);

	Padre::Action->new(
		name       => 'plugins.edit_my_plugin',
		label      => _T('Edit My Plug-in'),
		comment    => _T('My Plug-in is a plug-in where developers could extend their Padre installation'),
		menu_event => sub {
			my $file = File::Spec->catfile(
				Padre::Constant::CONFIG_DIR,
				qw{ plugins Padre Plugin My.pm }
			);
			return $self->error( _T("Could not find the Padre::Plugin::My plug-in") ) unless -e $file;

			# Use the plural so we get the "close single unused document"
			# behaviour, and so we get a free freezing and refresh calls.
			$_[0]->setup_editors($file);
		},
	);

	Padre::Action->new(
		name       => 'plugins.reload_my_plugin',
		label      => _T('Reload My Plug-in'),
		comment    => _T('This function reloads the My plug-in without restarting Padre'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_plugin('Padre::Plugin::My');
		},
	);

	Padre::Action->new(
		name       => 'plugins.reset_my_plugin',
		label      => _T('Reset My plug-in'),
		comment    => _T('Reset the My plug-in to the default'),
		menu_event => sub {
			my $ret = Wx::MessageBox(
				_T("Reset My plug-in"),
				_T("Reset My plug-in"),
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
		label      => _T('Reload All Plug-ins'),
		comment    => _T('Reload all plug-ins from disk'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_plugins;
		},
	);

	Padre::Action->new(
		name       => 'plugins.reload_current_plugin',
		label      => _T('(Re)load Current Plug-in'),
		comment    => _T('Reloads (or initially loads) the current plug-in'),
		menu_event => sub {
			Padre->ide->plugin_manager->reload_current_plugin;
		},
	);

	#	Padre::Action->new(
	#		$tools,
	#		name       => 'plugins.test_a_plugin',
	#		label      => _T('Test A Plugin From Local Dir'),
	#		menu_event => sub {
	#			Padre->ide->plugin_manager->test_a_plugin;
	#		},
	#	);


	Padre::Action->new(
		name       => 'plugins.install_cpan',
		label      => _T("Install CPAN Module"),
		comment    => _T('Install a Perl module from CPAN'),
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
		label      => _T("Install Local Distribution"),
		comment    => _T('Using CPAN.pm to install a CPAN like package opened locally'),
		menu_event => sub {
			$self->install_file( $_[0] );
		},
	);

	Padre::Action->new(
		name       => 'plugins.install_remote',
		label      => _T("Install Remote Distribution"),
		comment    => _T('Using pip to download a tar.gz file and install it using CPAN.pm'),
		menu_event => sub {
			$self->install_url( $_[0] );
		},
	);

	Padre::Action->new(
		name       => 'plugins.cpan_config',
		label      => _T("Open CPAN Config File"),
		comment    => _T('Open CPAN::MyConfig.pm for manual editing by experts'),
		menu_event => sub {
			$self->cpan_config( $_[0] );
		},
	);

	return $self;
}

#####################################################################
# Module Tools

sub install_file {
	my $self = shift;
	my $main = shift;

	# Ask what we should install
	my $dialog = Wx::FileDialog->new(
		$main,
		_T("Select distribution to install"),
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
		$main->error( _T("Did not provide a distribution") );
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
		_T("Enter URL to install\ne.g. http://svn.ali.as/cpan/releases/Config-Tiny-2.00.tar.gz"),
		"pip",
		'',
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error( _T("Did not provide a distribution") );
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
		$main->error( _T("pip is unexpectedly not installed") );
		return;
	}

	$main->setup_bindings;

	# Run with console Perl to prevent unexpected results under wperl
	my $perl = Padre::Perl::cperl();
	my $cmd  = qq{"$perl" "$pip" "$module"};
	local $ENV{AUTOMATED_TESTING} = 1;
	Wx::Perl::ProcessStream::Process->new->Run( $cmd, 'CPAN_mod', $main );

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

	$main->error( _T("Failed to find your CPAN configuration") );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
