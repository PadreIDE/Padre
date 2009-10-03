#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use FindBin qw/$RealBin/;

eval {
	require Win32::GuiTest;
	import Win32::GuiTest qw(:ALL);
};
if ($@) {
	plan skip_all => 'Win32::GuiTest is required for this test';
}

use t::lib::Padre;
require t::lib::Padre::Win32;
my $padre = t::lib::Padre::Win32::setup();
##############################

plan tests => 1;


SendKeys("{LEFT}"); # no selection
MenuSelect("&File|Open Selection");
sleep 1;

SendKeys("Wx::Perl::Dialog");
SendKeys("~");      # press Enter
sleep 1;

# check if the Padre.pm is open.
my @children = FindWindowLike( $padre, '', 'msctls_statusbar32' );
my $text = WMGetText( $children[0] );
like( $text, qr/Dialog\.pm$/, 'get Padre on statusbar' );

# Close it
MenuSelect("&File|&Close");


SendKeys("%{F4}");  # Alt-F4 to exit
sleep 1;
