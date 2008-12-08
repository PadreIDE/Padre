#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw/$RealBin/;
use vars qw/@windows/;

BEGIN {
    eval 'use Win32::GuiTest qw(:ALL);'; ## no critic (ProhibitStringyEval)
    $@ and plan skip_all => 'Win32::GuiTest is required for this test';
    
    @windows = FindWindowLike(0, "^Padre");
    scalar @windows or plan skip_all => 'You need open Padre then start this test';
};

plan tests => 2;

my $padre = $windows[0];
SetForegroundWindow($padre);
sleep 1;

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

open(my $fh, '<', "$dir/$save_to");
local $/;
my $text = <$fh>;
close($fh);
like($text, qr/inside Padre/);

# restore
MenuSelect("&File|&Close");
unlink("$dir/$save_to");

1;