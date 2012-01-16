#!/usr/bin/perl

use 5.008;
use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}
plan( tests => 37 );

use Test::Script;
use Test::NoWarnings;

local $^W = 1;

use_ok('Wx');
diag( "Tests find Wx: $Wx::VERSION " . Wx::wxVERSION_STRING() );

use_ok('t::lib::Padre');
use_ok('Padre::Util');
use_ok('Padre::Config');
use_ok('Padre::Config::Apply');
use_ok('Padre::Config::Project');
use_ok('Padre::DB::Timeline');
use_ok('Padre::DB');
use_ok('Padre::Project');
use_ok('Padre::Wx');
use_ok('Padre::Wx::HtmlWindow');
use_ok('Padre::Wx::Printout');
use_ok('Padre::Wx::Dialog::PluginManager');
use_ok('Padre::Wx::Dialog::Preferences');
use_ok('Padre::Wx::TextEntryDialog::History');
use_ok('Padre::Wx::ComboBox::History');
use_ok('Padre::Wx::ComboBox::FindTerm');
use_ok('Padre');
use_ok('Padre::Pod2HTML');
use_ok('Padre::Plugin::Devel');
use_ok('Padre::Plugin::My');

# Load all the second-generation modules
use_ok('Padre::Task');
use_ok('Padre::TaskWorker');
use_ok('Padre::TaskHandle');
use_ok('Padre::TaskManager');
use_ok('Padre::Role::Task');

# Now load everything else
my $loaded = Padre->import(':everything');
ok( $loaded, "Loaded the remaining $loaded classes ok" );

script_compiles('script/padre');

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
	script_compiles("share/examples/wx/$_");
}
