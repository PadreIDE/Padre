#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval {
	require Win32::GuiTest;
	import Win32::GuiTest qw(:ALL);
};
if ($@) {
	plan( skip_all => 'Win32::GuiTest is required for this test' );
}

#plan( skip_all => 'test is currently broken' );

use t::lib::Padre;
require t::lib::Padre::Win32;
my $padre = t::lib::Padre::Win32::setup();

################################

plan tests => 5;

#diag "Window id $padre";

my $menu = GetMenu($padre);

#diag "Menu id: $menu";

# test File Menu
my $submenu = GetSubMenu( $menu, 0 );
{
	my %h = GetMenuItemInfo( $menu, 0 );

	# The next test is locale specific so we might skip
	# the whole thing if not in English?
	is $h{text}, '&File', "File Menu is ok";
}

{
	my %h = GetMenuItemInfo( $submenu, 0 ); # New in the File menu
	is $h{text}, "&New\tCtrl-N", "New is the first menu item";
}
my $subsubmenu = GetSubMenu( $submenu, 1 );
{
	my %h = GetMenuItemInfo( $subsubmenu, 4 );
	is $h{text}, "Perl &6 Script", "Perl 6 Script in submenu";
}

# test Edit
{
	$submenu = GetSubMenu( $menu, 1 );
	my %h = GetMenuItemInfo( $menu, 1 );
	is $h{text}, '&Edit', 'Edit menu';
}

# test View
{
	$submenu = GetSubMenu( $menu, 3 );
	my %h = GetMenuItemInfo( $menu, 3 );
	is $h{text}, '&View', 'View Menu';
}

SendKeys("%{F4}"); # Alt-F4 to exit
sleep 1;
