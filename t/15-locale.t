#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 60 );
}
use Test::NoWarnings;
use t::lib::Padre;
use Padre;

# Create the IDE instance
my $app = Padre->new;
isa_ok( $app, 'Padre' );
my $main = $app->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );

# Change locales several times and make sure we don't suffer any
# crashes or warnings.
ok( $main->change_locale('ar'),    '->change_locale(ar)' );
ok( $main->change_locale('de'),    '->change_locale(de)' );
ok( $main->change_locale('en-au'), '->change_locale(en-au)' );
ok( $main->change_locale,          '->change_locale()' );
