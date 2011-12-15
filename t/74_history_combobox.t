#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 7;
}

use Test::NoWarnings;
use t::lib::Padre;
use Test::MockObject;

use Padre::Wx;


# Startup
my $mock_history_combobox = Test::MockObject->new();
$mock_history_combobox->set_isa('Wx::ComboBox');

use_ok('Padre::Wx::ComboBox::History');

SCOPE: {

	# Check item added to history when not already found

	# GIVEN
	$mock_history_combobox->set_always( 'FindString', Wx::wxNOT_FOUND );
	$mock_history_combobox->set_always( 'GetValue',   'foo' );
	$mock_history_combobox->{type} = 'test1';

	# WHEN
	my $value = Padre::Wx::ComboBox::History::SaveValue($mock_history_combobox);

	# THEN
	is( $value, 'foo', "SaveValue returned correct value" );
	my @history = Padre::DB::History->recent('test1');
	is( scalar @history, 1,     "One item in history list" );
	is( $history[0],     'foo', "Correct value in history" );
}

SCOPE: {

	# Check item not added to history when already exists

	# GIVEN
	$mock_history_combobox->set_always( 'FindString', 0 );
	$mock_history_combobox->{type} = 'test2';

	# WHEN
	my $value = Padre::Wx::ComboBox::History::SaveValue($mock_history_combobox);

	# THEN
	is( $value, 'foo', "SaveValue returned correct value" );
	my @history = Padre::DB::History->recent('test2');
	is( scalar @history, 0, "Item not recorded in history" );
}

1;
