#!/usr/bin/perl

# Tests for Padre::Wx::Editor

use strict;
use warnings;
use Test::More tests => 24;
use Test::NoWarnings;
use t::lib::Padre;
use Padre;

# Create an IDE with an unused editor
my $padre = Padre->new;
isa_ok( $padre, 'Padre' );
my $main = $padre->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );
$main->setup_editor;
my $editor = $main->current->editor;
isa_ok( $editor, 'Padre::Wx::Editor' );






######################################################################
# Introspection and Search

SCOPE: {
	# Test ->position
	is( $editor->position(), 0, '->position()' );
	is( $editor->position(undef), 0, '->position(undef)' );
	is( $editor->position(0), 0, '->position(0)' );
	is( $editor->position(-1), 0, '->position(-1)' );
	is( $editor->position(1), 0, '->position(1)' );

	# Test ->line
	is( $editor->line(), 0, '->line()' );
	is( $editor->line(undef), 0, '->line(undef)' );
	is( $editor->line(0), 0, '->line(0)' );
	is( $editor->line(-1), 0, '->line(-1)' );
	is( $editor->line(1), 0, '->line(1)' );

	# Test ->find_line
	$editor->SetText("A\nB\nC\nA\nE\nF\nA\nH");
	is( $editor->find_line( -1 => 'A' ), 0, '->find_line(0,A)' );
	is( $editor->find_line( 0 => 'A' ), 0, '->find_line(0,A)' );
	is( $editor->find_line( 1 => 'A' ), 0, '->find_line(0,A)' );
	is( $editor->find_line( 2 => 'A' ), 3, '->find_line(0,A)' );
	is( $editor->find_line( 3 => 'A' ), 3, '->find_line(0,A)' );
	is( $editor->find_line( 4 => 'A' ), 3, '->find_line(0,A)' );
	is( $editor->find_line( 5 => 'A' ), 6, '->find_line(0,A)' );
	is( $editor->find_line( 6 => 'A' ), 6, '->find_line(0,A)' );
	is( $editor->find_line( 7 => 'A' ), 6, '->find_line(0,A)' );
	is( $editor->find_line( 8 => 'A' ), 6, '->find_line(0,A)' );
}
