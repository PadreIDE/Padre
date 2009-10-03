#!/usr/bin/perl

use 5.008;
use strict;

BEGIN {
	$|  = 1;
	$^W = 1;
}
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}
plan( tests => 36 );
use Test::Script;
use Test::NoWarnings;

use_ok('Wx');
diag( "Tests find Wx: $Wx::VERSION " . Wx::wxVERSION_STRING() );

use_ok('t::lib::Padre');
use_ok('Padre::Util');
use_ok('Padre::Config');
use_ok('Padre::DB');
use_ok('Padre::Project');
use_ok('Padre::Wx');
use_ok('Padre::Wx::HtmlWindow');
use_ok('Padre::Wx::Printout');
use_ok('Padre::Wx::Dialog::PluginManager');
use_ok('Padre::Wx::Dialog::Preferences');
use_ok('Padre::Wx::History::TextEntryDialog');
use_ok('Padre::Wx::History::ComboBox');
use_ok('Padre');
use_ok('Padre::Pod2HTML');
use_ok('Padre::Plugin::Devel');
use_ok('Padre::Plugin::My');

script_compiles_ok('script/padre');

foreach ( 1 .. 9 ) {
	script_compiles_ok("share/timeline/migrate-$_.pl");
}

foreach (
	qw{
	01_simple_frame.pl
	02_label.pl
	03_button.pl
	04_button_with_event.pl
	05_button_with_event_and_message_box.pl
	21_progress_bar.pl
	22_notebook.pl
	30_editor.pl
	}
	)
{
	script_compiles_ok("share/examples/wx/$_");
}
