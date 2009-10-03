#!/usr/bin/perl

use strict;
use warnings;

my $CR   = "\015";
my $LF   = "\012";
my $CRLF = "\015\012";

use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 13;
}

use Test::NoWarnings;
use t::lib::Padre;
use Padre::Util ();

is( Padre::Util::newline_type("...")           => "None",  "None" );
is( Padre::Util::newline_type(".$CR.$CR.")     => "MAC",   "Mac" );
is( Padre::Util::newline_type(".$LF.$LF.")     => "UNIX",  "Unix" );
is( Padre::Util::newline_type(".$CRLF.$CRLF.") => "WIN",   "Windows" );
is( Padre::Util::newline_type(".$LF.$CR.")     => "Mixed", "Mixed" );
is( Padre::Util::newline_type(".$CR.$LF.")     => "Mixed", "Mixed" );
is( Padre::Util::newline_type(".$CRLF.$LF.")   => "Mixed", "Mixed" );
is( Padre::Util::newline_type(".$LF.$CRLF.")   => "Mixed", "Mixed" );
is( Padre::Util::newline_type(".$CR.$CRLF.")   => "Mixed", "Mixed" );
is( Padre::Util::newline_type(".$CRLF.$CR.")   => "Mixed", "Mixed" );
is( Padre::Util::newline_type(".$CR$LF$CR.")   => "Mixed", "Mixed" );
is( Padre::Util::newline_type(".$CR$LF$LF.")   => "Mixed", "Mixed" );
