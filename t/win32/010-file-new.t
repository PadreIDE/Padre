#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Win32;

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
############################

plan tests => 5;

# diag "Window id $padre";

my $text = "If you're reading this inside Padre, ";
$text .= "we might consider this test succesful. ";
$text .= "Please wait.......";

my $dir = Win32::GetLongPathName( $ENV{PADRE_HOME} );
diag "PADRE_HOME long path: '$dir'";
my $save_to  = "$dir/$$.txt";
my $save_tox = "$dir/x$$.txt";

# Stupid Save box don't accpect '/' in the input
$save_to  =~ s{/}{\\}g;
$save_tox =~ s{/}{\\}g;

diag "Save to '$save_to'";

SCOPE: {
	MenuSelect("&File|&New");
	sleep 1;

	unlink $save_to;

	#my @tabs = GetTabItems($padre);
	#my @children = FindWindowLike($padre, 'Unsaved');
	#my @children = GetChildWindows($padre);
	#my @stc = FindWindowLike('', '', 'stcwindow');
	#diag explain \@stc;
	#foreach my $child (@children) {
	#	diag sprintf "Child:  %8s  %s\n", $child, GetWindowText($child);
	#}
	#diag tree($padre);
	#SendKeys("%{F4}");  # Alt-F4 to exit
	#exit;

	SendKeys($text);
	MenuSelect("&File|&Save");
	sleep 1;

	SendKeys($save_to);
	SendKeys("%{S}");
	sleep 1;

	ok( -e $save_to, "file '$save_to' saved" );
	my $text_in_file = slurp($save_to);
	is( $text_in_file, $text, 'correct text in file' );
}

SCOPE: {
	my $t = "Text in second line...";
	SendKeys("{ENTER}");
	SendKeys($t);
	$text .= "\n$t";
	SendKeys("^{s}"); # Ctrl-s
	sleep 1;
	my $text_in_file = slurp($save_to);
	is( $text_in_file, $text, 'correct text in file' );
}

SCOPE: {
	SendKeys("{F12}"); # Save As
	sleep 1;

	SendKeys($save_tox);
	SendKeys("%{S}");
	sleep 1;

	ok( -e $save_tox, "file '$save_tox' saved" );
	my $text_in_file = slurp($save_tox);
	is( $text_in_file, $text, 'correct text in file' );
}

#{
#	SendKeys("^{n}");  # Ctrl-n
#	sleep 4;
#	SendKeys("text");
#	SendKeys("^{w}");  # Ctrl-w  closing the current window
#}
#

MenuSelect("&File|&Close");

SendKeys("%{F4}"); # Alt-F4 to exit
sleep 1;

sub slurp {
	if ( open( my $fh, '<', $save_to ) ) {
		local $/;
		my $rv = <$fh>;
		close $fh;
		return $rv;
	} else {
		warn("Could not open file $save_to  $!");
		return;
	}
}

sub tree {
	my ( $id, $depth ) = @_;
	$depth ||= 0;

	my $LIMIT    = 5;
	my @children = GetChildWindows($id);
	my $str      = '';
	if ( $depth >= $LIMIT ) {
		return ( ( "+" x $LIMIT ) . "Depth limit of $LIMIT reached\n" );
	}
	foreach my $child (@children) {
		$str .= ( "+" x $depth ) . sprintf "Child:  %8s  %s\n", $child, GetWindowText($child);
		$str .= tree( $child, $depth + 1 );
	}
	return $str;
}
