#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Capture::Tiny qw(capture);
use Cwd qw(cwd);
use File::Spec ();

my $messages_pot;
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 7 + 4 );
	$messages_pot = File::Spec->catfile(cwd(), 'share', 'locale', 'messages.pot');
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
lives_ok { $main->change_locale } '->change_locale()';


# a few sample strings some of them disappeard from messages.pot during the release of 0.82
# See ticket #1132
my @strings = (
	'Dump the Padre object to STDOUT',
	'Full Screen',
	'Check for Common (Beginner) Errors',
	'Run Script',
);

open my $fh, '<', $messages_pot or die "Could not open '$messages_pot' $!";
my @messages = <$fh>;
TODO:
{
local $TODO = 'messages.pot need to be regenarated before releasing 0.82 and merged to trunk';
foreach my $str (@strings) {
	ok grep({$_ =~ /\Q$str/} @messages), "messages.pot has entry '$str'";
}
}
