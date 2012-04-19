#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 31;
use Test::NoWarnings;
use t::lib::Padre;
use Padre::Locale::Format;





######################################################################
# Integers

my @integer = (
	''         => '',
	'Hello'    => 'Hello',
	'0'        => '0',
	'1'        => '1',
	'12'       => '12',
	'123'      => '123',
	'1234'     => '1,234',
	'12345'    => '12,345',
	'123456'   => '123,456',
	'1234567'  => '1,234,567',
	'-1'       => '-1',
	'-12'      => '-12',
	'-123'     => '-123',
	'-1234'    => '-1,234',
	'-12345'   => '-12,345',
	'-123456'  => '-123,456',
	'-1234567' => '-1,234,567',
);
is( Padre::Locale::Format::integer(undef),
	'',
	"integer undef --> ''",
);
while (@integer) {
	my $input = shift @integer;
	my $want  = shift @integer;
	my $have  = Padre::Locale::Format::integer($input);
	is( $have, $want, "integer $input --> $want" );
}





######################################################################
# Bytes

my @bytes = (
	''         => '',
	'Hello'    => 'Hello',
	'0'        => '0B',
	'1'        => '1B',
	'10'       => '10B',
	'100'      => '100B',
	'1000'     => '1000B',
	'10000'    => '9.8kB',
	'100000'   => '97.7kB',
	'1000000'  => '976.6kB',
	'10000000' => '9.5MB',
);
is( Padre::Locale::Format::bytes(undef),
	'',
	"bytes undef --> ''",
);
while (@bytes) {
	my $input = shift @bytes;
	my $want  = shift @bytes;
	my $have  = Padre::Locale::Format::bytes($input);
	is( $have, $want, "bytes $input --> $want" );
}
