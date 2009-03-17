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
############################

plan tests => 5;
diag "Window id $padre";


MenuSelect("&File|&New");
sleep 1;

my $text = "If you're reading this inside Padre, ";
$text   .= "we might consider this test succesful. ";
$text   .= "Please wait.......";


# TODO replace this with $ENV{PADRE_HOME} (now it breaks)
my $dir      = $RealBin;
my $save_to  = "$dir/$$.txt";
my $save_tox = "$dir/x$$.txt";
# Stupid Save box don't accpect '/' in the input
$save_to =~ s/\//\\/g;
$save_tox =~ s/\//\\/g;
unlink($save_to, $save_tox);
diag "Save to '$save_to'";

{
	SendKeys($text);
	MenuSelect("&File|&Save");
	sleep 1;

	SendKeys($save_to);
	SendKeys("%{S}");
	sleep 1;

	ok(-e $save_to, "file '$save_to' saved");
	my $text_in_file = slurp($save_to);
	is($text_in_file, $text, 'correct text in file');
}

{
	my $t = "Text in second line...";
	SendKeys("{ENTER}");
	SendKeys($t);
	$text .= "\n$t";
	SendKeys("^{s}");  # Ctrl-s
	sleep 1;
	my $text_in_file = slurp($save_to);
	is($text_in_file, $text, 'correct text in file');
}

{
	SendKeys("{F12}");  # Save As
	sleep 1;

	SendKeys($save_tox);
	SendKeys("%{S}");
	sleep 1;

	ok(-e $save_tox, "file '$save_tox' saved");
	my $text_in_file = slurp($save_tox);
	is($text_in_file, $text, 'correct text in file');	
}

# restore
MenuSelect("&File|&Close");
unlink($save_to);

SendKeys("%{F4}");  # Alt-F4 to exit
sleep 1;



sub slurp {
	if (open(my $fh, '<', $save_to)) {
		local $/;
		return <$fh>;
	} else {
		warn("Could not open file $save_to  $!");
		return;
	}
}