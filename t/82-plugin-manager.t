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

use FindBin      qw($Bin);
use File::Spec   ();
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
	is(
		$manager->plugin_dir,
		Padre::Constant::PLUGIN_DIR,
		'->plugin_dir ok',
	);
	is( keys %{$manager->plugins}, 0, 'Found no plugins' );
	ok(
		! defined($manager->load_plugins()),
		'load_plugins always returns undef'
	);

	# check if we have the plugins that come with Padre
	cmp_ok( keys %{$manager->plugins}, '>=', 1, 'Loaded at least one plugin' );
	ok( ! $manager->plugins->{'Development::Tools'}, 'No second level plugin' );
}

## Test loading single plugins
SCOPE: {
	my $manager = Padre::PluginManager->new($padre);
	is( keys %{$manager->plugins}, 0, 'No plugins loaded' );
	ok( ! $manager->load_plugin('Padre::Plugin::My'), 'Loaded My Plugin' );
	is( keys %{$manager->plugins}, 1, 'Loaded something' );
	my $handle = $manager->_plugin('Padre::Plugin::My');
	isa_ok( $handle, 'Padre::PluginHandle' );
	is( $handle->name, 'Padre::Plugin::My', 'Loaded My Plugin' );
	ok( $handle->disabled, 'My Plugin is disabled' );
	ok( $manager->unload_plugin('Padre::Plugin::My'), '->unload_plugin ok' );
	ok( ! defined($manager->plugins->{My}), 'Plugin no longer loaded' );
	is( eval("\$Padre::Plugin::My::VERSION"), undef, 'My Plugin was cleaned up' );
}

## Test With custom plugins
SCOPE: {
	my $custom_dir = File::Spec->catfile( $Bin, 'lib' );
	my $manager  = Padre::PluginManager->new( $padre,
		plugin_dir => $custom_dir,
	);
	is( $manager->plugin_dir, $custom_dir );
	is( keys %{$manager->plugins}, 0 );

	$manager->_load_plugins_from_inc;
	# cannot compare with the exact numbers as there might be plugins already installed
	cmp_ok(keys %{$manager->plugins}, '>=', 3, 'at least 3 plugins')
	or
	diag(Dumper(\$manager->plugins));

	ok( ! exists $manager->plugins->{'Development::Tools'},  'no second level plugin' );
	is( $manager->_plugin('TestPlugin')->class, 'Padre::Plugin::TestPlugin' );
	ok( !defined $manager->plugins->{'Test::Plugin'},        'no second level plugin' );

	# try load again
	my $st = $manager->load_plugin('TestPlugin');
	is( $st, undef );
}

# TODO: let the plugin manager do this: (so we'll also test it)
my $path = File::Spec->catfile( $Bin, 'files', 'plugins' );
#diag $path;
unshift @INC, $path;
#diag $ENV{PADRE_HOME};
my $english = setlocale(LC_CTYPE) eq 'en_US.UTF-8' ? 1 : 0;
SCOPE: {
	my $manager  = Padre::PluginManager->new($padre);
	$manager->load_plugin('A');
	is $manager->plugins->{'A'}->{status}, 'error', 'error in loading A';
	my $msg1 = $english ? qr/Plugin:A - Failed to load module/ : qr/.*/;
	like $manager->plugins->{'A'}->errstr, 
		qr/^$msg1: Global symbol "\$syntax_error" requires explicit package name at/,
		'text of error message';

	$manager->load_plugin('B');
	is $manager->plugins->{'B'}->{status}, 'error', 'error in loading B';
	my $msg2 = $english ? qr/Plugin:B - Not compatible with Padre::Plugin API. Need to be subclass of Padre::Plugin/ : qr/.*/;
	like $manager->plugins->{'B'}->errstr,
		qr/^$msg2/,
		'text of error message';

	$manager->load_plugin('C');
	is $manager->plugins->{'C'}->{status}, 'disabled', 'disabled in loading C';
	my $msg3 = $english ? qr/Plugin:C - Does not have menus/ : qr/.*/;
	like $manager->plugins->{'C'}->errstr,
		qr/$msg3/,
		'text of error message';
}
