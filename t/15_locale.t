#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Capture::Tiny qw(capture);

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 7 );
}
use Test::NoWarnings;
use Test::Exception;
use t::lib::Padre;
use Padre;

# Create the IDE instance
my $app = Padre->new;
isa_ok( $app, 'Padre' );
my $main = $app->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );

# Change locales several times and make sure we don't suffer any
# crashes or warnings.

# using Capture::Tiny to eliminate a test failure using prove --merge
my $res;
my ( $stdout, $stderr ) = capture { $res = $main->change_locale('ar') };

# diag $stdout;
# diag $stderr;
is( $res,                          undef, '->change_locale(ar)' );
is( $main->change_locale('de'),    undef, '->change_locale(de)' );
is( $main->change_locale('en-au'), undef, '->change_locale(en-au)' );
lives_ok { $main->change_locale } '->change_locale';

