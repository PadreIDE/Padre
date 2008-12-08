#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use FindBin qw/$RealBin/;
use vars qw/@windows/;

BEGIN {
    eval 'use Win32::GuiTest qw(:ALL);'; ## no critic (ProhibitStringyEval)
    $@ and plan skip_all => 'Win32::GuiTest is required for this test';
    
    @windows = FindWindowLike(0, "^Padre");
    scalar @windows or plan skip_all => 'You need open Padre then start this test';
};

plan tests => 1;

my $padre = $windows[0];
SetForegroundWindow($padre);
sleep 1;

MenuSelect("&File|&Open");
sleep 1;

my $dir = $RealBin;
# Stupid Save box don't accpect '/' in the input
$dir =~ s/\//\\/g;

SendKeys("$dir\\..\\files\\missing_brace_1.pl");
SendKeys("%{O}");
sleep 1;

# check if the missing_brace_1.pl is open.
my @children = FindWindowLike($windows[0], '', 'msctls_statusbar32');
my $text = WMGetText($children[0]);
like( $text, qr/missing_brace_1\.pl$/, 'get missing_brace_1.pl on statusbar' );

# Close it
MenuSelect("&File|&Close");

1;