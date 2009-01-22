#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 58;
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use File::Temp ();

BEGIN {
	$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
}
use Padre::Config2 ();

# Create the empty config file
my $empty = Padre::Config2->default_yaml;
open( FILE, '>', $empty ) or die "Failed to open $empty";
print FILE "--- {}\n";
close( FILE );

# Load the config
my $config = Padre::Config2->read;
isa_ok( $config, 'Padre::Config2' );
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
} keys %Padre::Config2::SETTING;
foreach my $name ( @names ) {
	is(
		$config->$name(),
		$Padre::Config2::DEFAULT{$name},
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

# Set a value
ok(
	$config->set( main_lockinterface => 0 ),
	'->set ok',
);
