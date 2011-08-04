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

plan tests => 2;


SendKeys("{LEFT}"); # no selection

#MenuSelect("&File|Open Selection");
SendKeys("^+{O}");
sleep 1;

# TODO "Open Selection" window should be in the air
my @current_windows = FindWindowLike( 0, "^Open selection" );
is( scalar @current_windows, 1, q{'Open Selection' window found} );

SendKeys("Padre::Document::Perl");
sleep 1;
SendKeys("{ENTER}");
sleep 2;

# if there is only one matching file then this will already open the file
# if there are two matching files then we will have a window opened with
# the list of files and we have to select
# "Choose file"
my @choose_file = FindWindowLike( 0, "Choose File" );
if (@choose_file) {
	diag "More than one files found";
	SendKeys("{ENTER}");
	sleep 2;
}

# check if the Padre.pm is open.
my @children = FindWindowLike( $padre, '', 'msctls_statusbar32' );
my $text = WMGetText( $children[0] );
like( $text, qr/Document.*Perl\.pm$/, 'get filename on statusbar' );

# Close it
MenuSelect("&File|&Close");


SendKeys("%{F4}"); # Alt-F4 to exit
sleep 1;


