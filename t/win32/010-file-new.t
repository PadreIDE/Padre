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

require t::lib::Padre::Win32;
my $padre = t::lib::Padre::Win32::setup();
############################

plan tests => 2;
diag "Window id $padre";


MenuSelect("&File|&New");
sleep 1;

Win32::GuiTest::SendKeys("If you're reading this inside Padre, ");
Win32::GuiTest::SendKeys("we might consider this test succesful. ");
Win32::GuiTest::SendKeys("Please wait.......");

my $dir = $RealBin;
# Stupid Save box don't accpect '/' in the input
$dir =~ s/\//\\/g;

MenuSelect("&File|&Save");
sleep 1;

my $save_to = "$$.txt";
unlink("$dir/$save_to");

# Stupid Save box don't accpect '/' in the input
SendKeys("$dir\\$save_to");
SendKeys("%{S}");
sleep 1;

# check the file
ok(-e "$dir/$save_to", 'file saved');

my $text;
if (open(my $fh, '<', "$dir/$save_to")) {
	local $/;
	$text = <$fh>;
	close($fh);
} else {
	diag("Could not open file $dir/$save_to  $!");
}
like($text, qr/inside Padre/);

# restore
MenuSelect("&File|&Close");
unlink("$dir/$save_to");

SendKeys("%{F4}");  # Alt-F4 to exit

