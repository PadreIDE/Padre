#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 29;

}

use FindBin qw($Bin);
use File::Spec ();
use Data::Dumper qw(Dumper);
use Test::NoWarnings;
use t::lib::Padre;
use Padre;
use Padre::Constant ();
use Padre::PluginManager;
use POSIX qw(locale_h);

my $padre = Padre->new;

# Test the default loading behaviour
SCOPE: {
	my $manager = Padre::PluginManager->new($padre);
	isa_ok( $manager, 'Padre::PluginManager' );
	is( $manager->plugin_dir,
		Padre::Constant::PLUGIN_DIR,
		'->plugin_dir ok',
	);
	is( keys %{ $manager->plugins }, 0, 'Found no plugins' );
	ok( !defined( $manager->load_plugins ),
		'load_plugins always returns undef'
	);

	# check if we have the plugins that come with Padre
	cmp_ok( keys %{ $manager->plugins }, '>=', 1, 'Loaded at least one plugin' );
	ok( !$manager->plugins->{'Development::Tools'}, 'No second level plugin' );
}

## Test loading single plugins
SCOPE: {
	my $manager = Padre::PluginManager->new($padre);
	is( keys %{ $manager->plugins }, 0, 'No plugins loaded' );

	# Load the plugin
	ok( !$manager->load_plugin('Padre::Plugin::My'), 'Loaded My Plugin' );
	is( keys %{ $manager->plugins }, 1, 'Loaded something' );
	my $handle = $manager->handle('Padre::Plugin::My');
	isa_ok( $handle, 'Padre::PluginHandle' );
	is( $handle->class, 'Padre::Plugin::My', 'Loaded My Plugin' );
	ok( $handle->disabled, 'My Plugin is disabled' );

	# Unload the plugin
	ok( $manager->unload_plugin('Padre::Plugin::My'), '->unload_plugin ok' );
	ok( !defined( $manager->plugins->{My} ),          'Plugin no longer loaded' );
	is( eval("\$Padre::Plugin::My::VERSION"), undef, 'My Plugin was cleaned up' );
}

## Test With custom plugins
SCOPE: {
	my $custom_dir = File::Spec->catfile( $Bin, 'lib' );
	my $manager = Padre::PluginManager->new(
		$padre,
		plugin_dir => $custom_dir,
	);
	is( $manager->plugin_dir,        $custom_dir );
	is( keys %{ $manager->plugins }, 0 );

	$manager->load_plugins;

	# cannot compare with the exact numbers as there might be plugins already installed
	cmp_ok( keys %{ $manager->plugins }, '>=', 3, 'at least 3 plugins' )
		or diag( Dumper( \$manager->plugins ) );

	ok( !exists $manager->plugins->{'Development::Tools'}, 'no second level plugin' );
	is( $manager->handle('Padre::Plugin::TestPlugin')->class, 'Padre::Plugin::TestPlugin' );
	ok( !defined $manager->plugins->{'Test::Plugin'}, 'no second level plugin' );

	# try load again
	my $st = $manager->load_plugin('Padre::Plugin::TestPlugin');
	is( $st, undef );
}

# TODO: let the plugin manager do this: (so we'll also test it)
my $path = File::Spec->catfile( $Bin, 'files', 'plugins' );

#diag $path;
unshift @INC, $path;

#diag $ENV{PADRE_HOME};
my $english = setlocale(LC_CTYPE) eq 'en_US.UTF-8' ? 1 : 0;
SCOPE: {
	my $manager = Padre::PluginManager->new($padre);

	$manager->load_plugin('Padre::Plugin::A');
	is $manager->plugins->{'Padre::Plugin::A'}->{status}, 'error', 'error in loading A';
	my $msg1 = $english ? qr/Padre::Plugin::A - Crashed while loading\:/ : qr/.*/;
	like $manager->plugins->{'Padre::Plugin::A'}->errstr,
		qr/^$msg1 Global symbol "\$syntax_error" requires explicit package name at/,
		'text of error message';

	$manager->load_plugin('Padre::Plugin::B');
	is $manager->plugins->{'Padre::Plugin::B'}->{status}, 'error', 'error in loading B';
	my $msg2 = $english ? qr/Padre::Plugin::B - Not a Padre::Plugin subclass/ : qr/.*/;
	like $manager->plugins->{'Padre::Plugin::B'}->errstr, qr/^$msg2/, 'text of error message';

	$manager->load_plugin('Padre::Plugin::C');
	is $manager->plugins->{'Padre::Plugin::C'}->{status}, 'disabled', 'disabled in loading C';

	# Doesn't have an error message since r6891:
	#	my $msg3 = $english ? qr/Padre::Plugin::C - Does not have menus/ : qr/.*/;
	#	like $manager->plugins->{'Padre::Plugin::C'}->errstr,
	#		qr/$msg3/,
	#		'text of error message';
	is $manager->plugins->{'Padre::Plugin::C'}->errstr, '', 'text of error message';
}
