#!/usr/bin/perl

use strict;
use warnings;
use constant NUMBER_OF_CONFIG_OPTIONS => 159;

# Move of Debug to Run Menu
use Test::More tests => NUMBER_OF_CONFIG_OPTIONS * 2 + 24;
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use File::Temp ();

BEGIN {
	$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
}
use Padre::Constant ();
use Padre::Config   ();

# Loading the configuration subsystem should NOT result in loading Wx
is( $Wx::VERSION, undef, 'Wx was not loaded during config load' );

# Create the empty config file
my $empty = Padre::Constant::CONFIG_HUMAN;
open( my $FILE, '>', $empty ) or die "Failed to open $empty";
print $FILE "--- {}\n";
close($FILE);

# Load the config
my $config = Padre::Config->read;
isa_ok( $config,        'Padre::Config' );
isa_ok( $config->host,  'Padre::Config::Host' );
isa_ok( $config->human, 'Padre::Config::Human' );
is( $config->project,        undef, '->project is undef' );

# Loading the config file should not result in Wx loading
is( $Wx::VERSION, undef, 'Wx was not loaded during config read' );

# Check that the defaults work
my @names =
	sort { length($a) <=> length($b) or $a cmp $b } keys %Padre::Config::SETTING;
is( scalar(@names), NUMBER_OF_CONFIG_OPTIONS, 'Expected number of config options' );
foreach my $name (@names) {
	ok( defined( $config->$name() ), "->$name is defined" );
	is( $config->$name(),
		$Padre::Config::DEFAULT{$name},
		"->$name defaults ok",
	);
}

# The config version number is a requirement for every config and
# the only key which is allowed to live in an empty config.
my %test_config = ();

# ... and that they don't leave a permanent state.
is_deeply(
	+{ %{ $config->human } }, \%test_config,
	'Defaults do not leave permanent state (human)',
);
is_deeply(
	+{ %{ $config->host } }, \%test_config,
	'Defaults do not leave permanent state (host)',
);

# Store the config again
ok( $config->write, '->write ok' );

# Saving the config file should not result in Wx loading
is( $Wx::VERSION, undef, 'Wx was not loaded during config write' );

# Set values on both the human and host sides
ok( $config->set( main_lockinterface => 0 ),
	'->set(human) ok',
);
ok( $config->set( main_maximized => 1 ),
	'->set(host) ok',
);

# Save the config again
ok( $config->write, '->write ok' );

# Read in a fresh version of the config
my $config2 = Padre::Config->read;

# Confirm the config is round-trip safe
is_deeply( $config2, $config, 'Config round-trips ok' );

# No configuration operations require loading Wx
is( $Wx::VERSION, undef, 'Wx is never loaded during config operations' );

# Check clone support
my $copy = $config->clone;
is_deeply( $copy, $config, '->clone ok' );





######################################################################
# Check configuration values not in the relevant option list

SCOPE: {
	my $bad = Padre::Config->new(
		Padre::Config::Host->_new(
			{

				# Invalid option
				lang_perl5_lexer => 'Bad::Class::Does::Not::Exist',
			}
		),
		bless {
			revision => Padre::Config::Human->VERSION,

			# Valid option
			startup_files => 'new',

			# Invalid key
			nonexistant => 'nonexistant',
		},
		'Padre::Config::Human'
	);
	isa_ok( $bad,        'Padre::Config' );
	isa_ok( $bad->host,  'Padre::Config::Host' );
	isa_ok( $bad->human, 'Padre::Config::Human' );
	is( $bad->startup_files, 'new', '->startup_files ok' );

	# Configuration should ignore a value not in configuration and go
	# with the default instead.
	is( $bad->default('lang_perl5_lexer'), '', 'Default Perl 5 lexer ok' );
	is( $bad->lang_perl5_lexer,            '', '->lang_perl5_lexer matches default' );
}
