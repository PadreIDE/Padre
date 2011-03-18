#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 8;
}

use Test::NoWarnings;
use t::lib::Padre;
use Padre::Wx;
use Padre;
use_ok( 'Padre::Wx::Dialog::Preferences2' );

# Create the IDE
my $padre = new_ok('Padre');
my $main  = $padre->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );

# Create the Preferences 2.0 dialog
my $dialog = new_ok( 'Padre::Wx::Dialog::Preferences2', [ $main ] );

# Load the dialog from configuration
my $config = $main->config;
isa_ok( $config, 'Padre::Config' );
ok( $dialog->load($config), '->load ok' );

# The diff (extracted from dialog) to the config should be null
my $diff = $dialog->diff($config);
is_deeply( $diff, { }, '->diff returns an empty HASH' );
