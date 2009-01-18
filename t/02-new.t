#!/usr/bin/perl

use strict;
use warnings;
# use Test::NeedsDisplay ':skip_all';
use Test::More;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}
plan( tests => 20 );
use Test::NoWarnings;
use t::lib::Padre;
use Padre;

my $app = Padre->new;
isa_ok($app, 'Padre');

SCOPE: {
	my $inst = Padre->inst;
	isa_ok($inst, 'Padre');
	refis( $inst, $app, '->inst matches ->new' );

	my $ide = Padre->ide;
	isa_ok($ide, 'Padre');
	refis( $ide, $app, '->ide matches ->new' );
}

SCOPE: {
	my $config = $app->config;
	is_deeply( $config, {
		experimental             => 0,

		main_startup             => 'new',
		main_lockinterface       => 1,
		main_functions           => 0,
		main_outline             => 0,
		main_output              => 0,
		main_syntaxcheck         => 0,
		main_errorlist           => 0,
		main_statusbar           => 1,

		editor_font              => undef,
		editor_linenumbers       => 1,
		editor_eol               => 0,
		editor_indentationguides => 0,
		editor_calltips          => 0,
		editor_autoindent        => 'deep',
		main_functions_order           => 'alphabetical',
		editor_whitespace        => 0,
		editor_folding           => 0,
		editor_wordwrap          => 0,
		editor_currentline       => 0,
		editor_currentline_color => 'FFFF04',
		editor_indent_auto       => 1,
		editor_indent_tab_width  => 8,
		editor_indent_width      => 8,
		editor_indent_tab        => 1,
		editor_beginner          => 1,
		main_output_ansi              => 1,

		ppi_highlight            => 0,
		ppi_highlight_limit      => 10_000,

		run_save                 => 'same',
		threads                  => 1,

		diagnostics_lang         => '',

		host => {
			editor_style   => 'default',
			main_maximized => 0,
			main_top       => 20,
			main_left      => 40,
			main_width     => 600,
			main_height    => 400,
			main_file      => undef,
			main_files     => [],
			main_files_pos => [],
		},
	}, 'defaults' );
}





#####################################################################
# Internal Structure Tests

# These test that the internal structure of the application matches
# expected normals, and that structure navigation methods works normally.
SCOPE: {
	my $padre = Padre->ide;
	isa_ok( $padre, 'Padre' );

	# The Wx::App(lication)
	my $app = $padre->wx;
	isa_ok( $app, 'Padre::Wx::App' );

	# The main window
	my $main = $app->main;
	isa_ok( $main, 'Padre::Wx::Main' );

	# The main menu
	my $menu = $main->menu;
	isa_ok( $menu, 'Padre::Wx::Menubar' );
	refis( $menu->win,  $main, 'Menubar ->win gets the main window' );
	refis( $menu->main, $main, 'Menubar ->main gets the main window' );

	# A submenu
	my $file = $menu->file;
	isa_ok( $file, 'Padre::Wx::Menu' );

	# The notebook
	my $notebook = $main->notebook;
	isa_ok( $notebook, 'Padre::Wx::Notebook' );

	# Current context
	my $current = $main->current;
	isa_ok( $current, 'Padre::Current' );
	isa_ok( $current->main,     'Padre::Wx::Main' );
	isa_ok( $current->notebook, 'Padre::Wx::Notebook'   );
	refis(  $current->main,     $main,     '->current->main ok'     );
	refis(  $current->notebook, $notebook, '->current->notebook ok' );
}
