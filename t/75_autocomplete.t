#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 12;
}

use Test::NoWarnings;
use t::lib::Padre;
use Test::MockObject;

# Setup
my $mock_editor = Test::MockObject->new();
$mock_editor->set_true('AutoCompSetChooseSingle');
$mock_editor->set_true('AutoCompSetSeparator');
$mock_editor->set_true('AutoCompShow');

my $mock_document = Test::MockObject->new();
$mock_document->mock( 'autocomplete', sub { return ( 1, 'abc', 'def' ) } );
$mock_document->set_always( 'editor', $mock_editor );

my $mock_config = Test::MockObject->new();

my $mock_main = Test::MockObject->new();
$mock_main->set_always( 'current',  $mock_main );
$mock_main->set_always( 'document', $mock_document );
$mock_main->set_always( 'ide',      $mock_main );
$mock_main->set_always( 'config',   $mock_config );


$mock_main->fake_module(
	'Wx::Event',
	EVT_KILL_FOCUS => sub { }
);

use_ok('Padre::Wx::Main');

SCOPE: {

	# Test 'Set Single' turned on for autocomplete

	# GIVEN
	$mock_config->set_always( 'autocomplete_always', 0 );

	# WHEN
	Padre::Wx::Main::on_autocompletion($mock_main);

	# THEN
	my ( $name, $args );

	# Check AutoCompSetChooseSingle set
	( $name, $args ) = $mock_editor->next_call();
	is( $name, 'AutoCompSetChooseSingle', "AutoCompSetChooseSingle called" );
	is( $args->[1], 1, "AutoCompSetChooseSingle set to true" );

	# Check correct params passed to AutoCompShow
	( $name, $args ) = $mock_editor->next_call(2);
	is( $name,      'AutoCompShow', "AutoCompShow called" );
	is( $args->[1], 1,              "Length passed to AutoCompShow" );
	is( $args->[2], 'abc def',      "World list passed to AutoCompShow" );
}

SCOPE: {

	# Test 'Set Single' turned kept off when autocomplete_always is on

	# GIVEN
	$mock_config->set_always( 'autocomplete_always', 1 );

	# WHEN
	Padre::Wx::Main::on_autocompletion($mock_main);

	# THEN
	my ( $name, $args );

	# Check AutoCompSetChooseSingle set
	( $name, $args ) = $mock_editor->next_call();
	is( $name, 'AutoCompSetChooseSingle', "AutoCompSetChooseSingle called" );
	is( $args->[1], 0, "AutoCompSetChooseSingle set to false" );

	# Check correct params passed to AutoCompShow
	( $name, $args ) = $mock_editor->next_call(2);
	is( $name,      'AutoCompShow', "AutoCompShow called" );
	is( $args->[1], 1,              "Length passed to AutoCompShow" );
	is( $args->[2], 'abc def',      "World list passed to AutoCompShow" );
}
