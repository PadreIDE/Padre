#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;

}

use constant CONFIG_OPTIONS => 61;

# Move of Debug to Run Menu
use Test::More tests => CONFIG_OPTIONS * 2 + 17;
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use File::Temp ();
BEGIN {
	$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
}
use Padre::Constant ();
use Padre::Config   ();

# Create the empty config file
my $empty = Padre::Constant::CONFIG_HUMAN;
open( FILE, '>', $empty ) or die "Failed to open $empty";
print FILE "--- {}\n";
close( FILE );

# Load the config
my $config = Padre::Config->read;
isa_ok( $config, 'Padre::Config' );
isa_ok( $config->host,  'Padre::Config::Host'  );
isa_ok( $config->human, 'Padre::Config::Human' );
is( $config->project, undef, '->project is undef' );
is( $config->host->version,  undef, '->host->version is undef'  );
is( $config->human->version, undef, '->human->version is undef' );

# Check that the defaults work
my @names = sort {
	length($a) <=> length($b)
	or
	$a cmp $b
} keys %Padre::Config::SETTING;
is (scalar(@names), CONFIG_OPTIONS, 'Expected number of config options');
foreach my $name ( @names ) {
	ok( defined($config->$name()), "->$name is defined" );	
	is(
		$config->$name(),
		$Padre::Config::DEFAULT{$name},
		"->$name defaults ok",
	);
}

# ... and that they don't leave a permanent state.
is_deeply(
	+{ %{ $config->human } }, {},
	'Defaults do not leave permanent state (human)',
);
is_deeply(
	+{ %{ $config->host } }, {},
	'Defaults do not leave permanent state (host)',
);

# Store the config again
ok( $config->write, '->write ok' );

# Check that we have a version for the parts now
is( $config->host->version,  1, '->host->version is set'  );
is( $config->human->version, 1, '->human->version is set' );

# Set values on both the human and host sides
ok(
	$config->set( main_lockinterface => 0 ),
	'->set(human) ok',
);
ok(
	$config->set( main_maximized => 1 ),
	'->set(host) ok',
);

# Save the config again
ok( $config->write, '->write ok' );

# Read in a fresh version of the config
my $config2 = Padre::Config->read;

# Confirm the config is round-trip safe
is_deeply( $config2, $config, 'Config round-trips ok' );
