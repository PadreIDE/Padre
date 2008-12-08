#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;
use Test::More;
my $tests;

plan tests => $tests;

use t::lib::Padre::Editor;

ok(1);
BEGIN { $tests += 1; }

my $e = t::lib::Padre::Editor->new;

my $text = <<"END_TEXT";
This is the first line
A second line
and there is even a third line
END_TEXT


{
	diag "Testing the t::lib::Padre::Editor a bit";
	$e->SetText($text);
	is($e->GetText($text), $text);

	is($e->GetCurrentPos, 0);
	
	is($e->LineFromPosition(0), 0);
	is($e->LineFromPosition(20), 0);
	is($e->LineFromPosition(22), 0);
	is($e->LineFromPosition(23), 1);
	is($e->LineFromPosition(24), 1);
	
	is($e->GetLineEndPosition(0), 23);
	
	is($e->PositionFromLine(0), 0);
	is($e->PositionFromLine(1), 23);
	
	is($e->GetColumn(0), 0);
	is($e->GetColumn(5), 5);
	is($e->GetColumn(22), 22);
	is($e->GetColumn(23), 0);
	is($e->GetColumn(24), 1);
	BEGIN { $tests += 1+1+5+1+2+5; }
}


