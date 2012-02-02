#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 19;
use Test::NoWarnings;
use t::lib::Padre;
use Padre::Locale::Format;

# Format a simple integer
my @integer = (
	''        => '',
	'Hello'   => 'Hello',
	'0'       => '0',
	'1'       => '1',
	'12'      => '12',
	'123'     => '123',
	'1234'    => '1,234',
	'12345'   => '12,345',
	'123456'  => '123,456',
	'1234567' => '1,234,567',
	'-1'       => '-1',
	'-12'      => '-12',
	'-123'     => '-123',
	'-1234'    => '-1,234',
	'-12345'   => '-12,345',
	'-123456'  => '-123,456',
	'-1234567' => '-1,234,567',
);
is(
	Padre::Locale::Format::integer(undef),
	'',
	"integer undef --> ''",
);
while ( @integer ) {
	my $input = shift @integer;
	my $want  = shift @integer;
	my $have  = Padre::Locale::Format::integer($input);
	is( $have, $want, "integer $input --> $want" );
}
