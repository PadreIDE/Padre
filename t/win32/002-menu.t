#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;

eval {
	require Win32::GuiTest;
	import Win32::GuiTest qw(:ALL);
};
if ($@) {
	plan skip_all => 'Win32::GuiTest is required for this test';
}
    
my %existing_windows = map {$_ => 1} FindWindowLike(0, "^Padre");


my $cmd = "start $^X script\\padre";
diag $cmd;
system $cmd;
our $padre;

# allow some time to launch Padre
foreach (1..10) {
	sleep(1);
	my @current_windows = FindWindowLike(0, "^Padre");
	my @wins = grep { ! $existing_windows{$_} } @current_windows;
	die "Too many Padres found '@wins'" if @wins > 1;
	$padre = shift @wins;
	last if $padre;
}
die "Could not find Padre" if not $padre;

SetForegroundWindow($padre);
sleep 1; # crap, we have to wait for Padre to come to the foreground
my $fg = GetForegroundWindow();
die "Padre is NOT in the foreground" if $fg ne $padre;

########

plan tests => 5;

diag "Window id $padre";




my $menu = GetMenu($padre);
diag "Menu id: $menu";

# test File Menu
my $submenu = GetSubMenu($menu, 0);
{
	my %h = GetMenuItemInfo($menu, 0);
	# The next test is locale specific so we might skip
	# the whole thing if not in English?
	is $h{text}, '&File', "File Menu is ok";
}

{
	my %h = GetMenuItemInfo($submenu, 0);   # New in the File menu
	is $h{text}, "&New\tCtrl-N", "New is the first menu item";
}
my $subsubmenu = GetSubMenu($submenu, 1);
{
	my %h = GetMenuItemInfo($subsubmenu, 0);
	is $h{text}, "Perl Distribution (Module::Starter)", "Module::Starter menu";
}

# test Edit
{
	$submenu = GetSubMenu($menu, 1);
	my %h = GetMenuItemInfo($menu, 1);
	is $h{text}, '&Edit', 'Edit menu';
}

# test View
{
	$submenu = GetSubMenu($menu, 3);
	my %h = GetMenuItemInfo($menu, 3);
	is $h{text}, '&View', 'View Menu';
}

SendKeys("%{F4}");  # Alt-F4 to exit

