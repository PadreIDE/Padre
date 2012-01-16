#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 63 );
}
use Test::NoWarnings;
use t::lib::Padre;
use Padre;

my $app = Padre->new;
isa_ok( $app, 'Padre' );

SCOPE: {
	my $ide = Padre->ide;
	isa_ok( $ide, 'Padre' );
	refis( $ide, $app, '->ide matches ->new' );
}

SCOPE: {
	my $ide = Padre::Current->ide;
	isa_ok( $ide, 'Padre' );
	refis( $ide, $app, '->ide matches ->new' );
}

SCOPE: {
	my $config = $app->config;
	isa_ok( $config, 'Padre::Config' );

	is( $config->startup_files        => 'new' );
	is( $config->main_lockinterface   => 1 );
	is( $config->main_functions       => 0 );
	is( $config->main_functions_order => 'alphabetical' );
	is( $config->main_outline         => 0 );
	is( $config->main_directory       => 0 );
	is( $config->main_output          => 0 );
	is( $config->main_output_ansi     => 1 );
	is( $config->main_syntax          => 0 );
	is( $config->main_statusbar       => 1 );

	my $editor_font = $config->editor_font;
	if ( $^O eq 'MSWin32' ) {
		ok( ( $editor_font eq '' ) || ( $editor_font eq 'consolas 10' ),
			'editor_font is either empty or consolas 10 on win32'
		);
	} else {
		is( $editor_font => '' );
	}

	is( $config->editor_linenumbers       => 1 );
	is( $config->editor_eol               => 0 );
	is( $config->editor_indentationguides => 0 );
	is( $config->editor_calltips          => 0 );
	is( $config->editor_autoindent        => 'deep' );
	is( $config->editor_whitespace        => 0 );
	is( $config->editor_folding           => 0 );
	is( $config->editor_wordwrap          => 0 );
	is( $config->editor_currentline       => 1 );
	is( $config->editor_currentline_color => 'FFFF04' );
	is( $config->editor_indent_auto       => 1 );
	is( $config->editor_indent_tab_width  => 8 );
	is( $config->editor_indent_width      => 8 );
	is( $config->editor_indent_tab        => 1 );
	is( $config->lang_perl5_beginner      => 1 );
	is( $config->find_case                => 1 );
	is( $config->find_regex               => 0 );
	is( $config->find_reverse             => 0 );
	is( $config->find_first               => 0 );
	is( $config->find_nohidden            => 1 );
	is( $config->run_save                 => 'same' );
	is( $config->threads                  => 1 );
	is( $config->locale                   => '' );
	is( $config->locale_perldiag          => '' );
	is( $config->editor_style             => 'default' );
	is( $config->main_maximized           => 0 );
	is( $config->main_top                 => -1 );
	is( $config->main_left                => -1 );
	is( $config->main_width               => -1 );
	is( $config->main_height              => -1 );
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

	# By default, most of the tools shouldn't exist
	ok( !$main->has_output,  '->has_output is false' );
	ok( !$main->has_outline, '->has_outline is false' );
	ok( !$main->has_syntax,  '->has_syntax is false' );

	# The main menu
	my $menu = $main->menu;
	isa_ok( $menu, 'Padre::Wx::Menubar' );
	refis( $menu->main, $main, 'Menubar ->main gets the main window' );

	# A submenu
	my $file = $menu->file;
	isa_ok( $file, 'Padre::Wx::Menu' );

	# The notebook
	my $notebook = $main->notebook;
	isa_ok( $notebook, 'Padre::Wx::Notebook' );

	# Current context
	my $current = $main->current;
	isa_ok( $current,           'Padre::Current' );
	isa_ok( $current->main,     'Padre::Wx::Main' );
	isa_ok( $current->notebook, 'Padre::Wx::Notebook' );
	refis( $current->main,     $main,     '->current->main ok' );
	refis( $current->notebook, $notebook, '->current->notebook ok' );
}
