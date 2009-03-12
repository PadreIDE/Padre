#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
our @windows;

BEGIN {
    eval 'use Win32::GuiTest qw(:ALL);'; ## no critic (ProhibitStringyEval)
    $@ and plan skip_all => 'Win32::GuiTest is required for this test';
    
    @windows = FindWindowLike(0, "^Padre");
    scalar @windows or plan skip_all => 'You need open Padre then start this test';
};

plan tests => 5;

my $padre = $windows[0];

my $menu = GetMenu($padre);

# test File
my $submenu = GetSubMenu($menu, 0);
my %h = GetMenuItemInfo($menu, 0);
is $h{text}, '&File';
%h = GetMenuItemInfo($submenu, 0);   # New in the File menu
is $h{text}, "&New\tCtrl-N";
my $subsubmenu = GetSubMenu($submenu, 1);
%h = GetMenuItemInfo($subsubmenu, 0);
is $h{text}, "Perl Distribution (Module::Starter)";

# test Edit
$submenu = GetSubMenu($menu, 1);
%h = GetMenuItemInfo($menu, 1);
is $h{text}, '&Edit';

# test View
$submenu = GetSubMenu($menu, 2);
%h = GetMenuItemInfo($menu, 2);
is $h{text}, '&View';

1;
