#!/usr/bin/perl

use strict;
use warnings;
use Test::NeedsDisplay ':skip_all';
use Test::More tests => 20;
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
	is_deeply  $config,
		{
		experimental       => 0,

		editor_linenumbers => 0,
		editor_eol         => 0,
		editor_indentationguides => 0,
		editor_calltips    => 1,
		editor_autoindent  => 'deep',
		editor_methods     => 'alphabetical',
		editor_whitespaces => 0,
		editor_codefolding => 0,

		editor_auto_indentation_style => 0,
		editor_tabwidth               => 8,
		editor_indentwidth            => 4,
		editor_use_tabs               => 1,
		editor_perl5_beginner         => 1,

		ppi_highlight                 => 0,
		ppi_highlight_limit           => 10_000,

		search_terms       => [],
		replace_terms      => [],
		main_startup       => 'new',
		main_statusbar     => 1,
		main_output        => 0,
		main_rightbar      => 1,
		main_lockpanels    => 0,
		projects           => {},
		run_save           => 'same',
		current_project    => '',
		bookmarks          => {},

		host               => {
			main_maximized => 0,
			main_top       => 20,
			main_left      => 40,
			main_width     => 600,
			main_height    => 400,
			run_command    => '',
			main_files     => [],
			main_files_pos => [],
			style          => 'default',
		},
		main_subs_panel   => 0,
		main_output_panel => 0,

		plugins => {},
		use_worker_threads        => 1,
	},
	'defaults';
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
	my $main = $app->main_window;
	isa_ok( $main, 'Padre::Wx::MainWindow' );

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
	isa_ok( $current->_main,     'Padre::Wx::MainWindow' );
	isa_ok( $current->_notebook, 'Padre::Wx::Notebook'   );
	refis(  $current->_main,     $main,     '->current->_main ok'     );
	refis(  $current->_notebook, $notebook, '->current->_notebook ok' );
}
