#!/usr/bin/perl

use strict;
use warnings;

use FindBin      qw($Bin);
use File::Spec   ();
use Data::Dumper qw(Dumper);

use Test::More;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

plan tests => 25;

use Test::NoWarnings;

use t::lib::Padre;
use Padre;

use_ok('Padre::PluginManager');

my $padre = Padre->new();
my $plugin_m1 = Padre::PluginManager->new($padre);
isa_ok $plugin_m1, 'Padre::PluginManager';

is $plugin_m1->plugin_dir, Padre::Config->default_plugin_dir;
is keys %{$plugin_m1->plugins}, 0;

ok !defined($plugin_m1->load_plugins()), 'load_plugins always returns undef';


# check if we have the plugins that come with Padre
cmp_ok (keys %{$plugin_m1->plugins}, '>=', 1);
#is $plugin_m1->plugins->{'Development::Tools'},  'Padre::Plugin::Development::Tools';
ok !$plugin_m1->plugins->{'Development::Tools'},  'no second level plugin';

# try load again
#{
#my $st = $plugin_m1->load_plugin('Development::Tools');
#is $st, undef;
#}

## Test loading single plugins
$plugin_m1 = Padre::PluginManager->new($padre);
is keys %{$plugin_m1->plugins}, 0;
ok(!$plugin_m1->load_plugin('My'));
is keys %{$plugin_m1->plugins}, 1;
is( $plugin_m1->plugins->{My}{status}, 'disabled' );
$padre->config->{plugins}{My}{enabled} = 1;
ok($plugin_m1->load_plugin('My'));
is( $plugin_m1->plugins->{My}{status}, 'enabled' );
ok($plugin_m1->reload_plugin('My'));
is( $plugin_m1->plugins->{My}{status}, 'enabled' );
ok($plugin_m1->unload_plugin('My'));
ok( !defined($plugin_m1->plugins->{My}) );


## Test With custom plugins
my $custom_dir = File::Spec->catfile( $Bin, 'lib' );
my $plugin_m2  = Padre::PluginManager->new($padre, plugin_dir => $custom_dir);

is $plugin_m2->plugin_dir, $custom_dir;
is keys %{$plugin_m2->plugins}, 0;

$plugin_m2->_load_plugins_from_inc();
# cannot compare with the exact numbers as there might be plugins already installed
cmp_ok (keys %{$plugin_m2->plugins}, '>=', 3, 'at least 3 plugins')
	or diag(Dumper(\$plugin_m2->plugins));

#is $plugin_m2->plugins->{'Development::Tools'},  'Padre::Plugin::Development::Tools';
ok !exists $plugin_m2->plugins->{'Development::Tools'},  'no second level plugin';
is $plugin_m2->plugins->{TestPlugin}{module},     'Padre::Plugin::TestPlugin';
#is $plugin_m2->plugins->{'Test::Plugin'},        'Padre::Plugin::Test::Plugin';
ok !defined $plugin_m2->plugins->{'Test::Plugin'},        'no second level plugin';

# try load again
{
	my $st = $plugin_m2->load_plugin('TestPlugin');
	is $st, undef;
}

### XXX? TODO, test par

1;
