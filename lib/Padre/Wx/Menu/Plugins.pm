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

our $VERSION = '0.50';
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
	$self->add_menu_action(
		$self,
		'plugins.plugin_manager',
	);

	# Create the plugin tools submenu
	my $tools = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Plug-in Tools'),
		$tools,
	);

	# TO DO: should be replaced by a link to http://cpan.uwinnipeg.ca/chapter/World_Wide_Web_HTML_HTTP_CGI/Padre
	# better yet, by a window that also allows the installation of all the plugins that can take into account
	# the type of installation we have (ppm, stand alone, rpm, deb, CPAN, etc.)
	$self->add_menu_action(
		$tools,
		'plugins.plugin_list',
	);

	$tools->AppendSeparator;

	$self->add_menu_action(
		$tools,
		'plugins.edit_my_plugin',
	);

	$self->add_menu_action(
		$tools,
		'plugins.reload_my_plugin',
	);

	$self->add_menu_action(
		$tools,
		'plugins.reset_my_plugin',
	);

	$tools->AppendSeparator;

	$self->add_menu_action(
		$tools,
		'plugins.reload_all_plugins',
	);

	$self->add_menu_action(
		$tools,
		'plugins.reload_current_plugin',
	);

	#	$self->add_menu_action(
	#		$tools,
	#		'plugins.test_a_plugin',
	#	);

	# Create the module tools submenu
	my $modules = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Module Tools'),
		$modules,
	);

	$self->add_menu_action(
		$modules,
		'plugins.install_cpan',
	);

	$self->add_menu_action(
		$modules,
		'plugins.install_local',
	);

	$self->add_menu_action(
		$modules,
		'plugins.install_remote',
	);

	$modules->AppendSeparator;

	$self->add_menu_action(
		$modules,
		'plugins.cpan_config',
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

sub title {
	my $self = shift;

	return Wx::gettext('Pl&ugins');
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

	$main->error( Wx::gettext("Failed to find your CPAN configuration") );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
