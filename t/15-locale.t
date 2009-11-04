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
is( $main->change_locale('ar'), undef, '->change_locale(ar)' );
is( $main->change_locale('de'), undef, '->change_locale(de)' );
is( $main->change_locale('en-au'), undef, '->change_locale(en-au)' );
is( $main->change_locale, undef, '->change_locale()' );
