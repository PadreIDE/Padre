#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw/$RealBin/;

eval {
	require Win32::GuiTest;
	import Win32::GuiTest qw(:ALL);
};
if ($@) {
	plan skip_all => 'Win32::GuiTest is required for this test';
}

#plan( skip_all => 'test is currently broken' );

use t::lib::Padre;
require t::lib::Padre::Win32;
my $padre = t::lib::Padre::Win32::setup();
##############################

plan tests => 1;

MenuSelect("&File|&Open");
sleep 1;

my $dir = $RealBin;

# Stupid Save box don't accpect '/' in the input
$dir =~ s/\//\\/g;

diag $dir;
my $file = "$dir\\..\\files\\missing_brace_1.pl";
diag "File to open: $file";
SendKeys($file);
SendKeys("%{O}");
sleep 1;

# check if the missing_brace_1.pl is open.
my @children = FindWindowLike( $padre, '', 'msctls_statusbar32' );
my $text = WMGetText( $children[0] );
like( $text, qr/missing_brace_1\.pl$/, 'get missing_brace_1.pl on statusbar' );

# Close it
MenuSelect("&File|&Close");

SendKeys("%{F4}"); # Alt-F4 to exit
sleep 1;
