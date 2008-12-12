#!/usr/bin/perl

use strict;
use warnings;
use Test::NeedsDisplay;

my $CR   = "\015";
my $LF   = "\012";
my $CRLF = "\015\012";

use Test::More;
use Test::NoWarnings;
use t::lib::Padre;
use Padre::Util 'newline_type';

my $tests;
plan tests => $tests+1;

SCOPE: {
    is(newline_type("...") => "None", "None");
    is(newline_type(".$CR.$CR.") => "MAC", "Mac");
    is(newline_type(".$LF.$LF.") => "UNIX", "Unix");
    is(newline_type(".$CRLF.$CRLF.") => "WIN", "Windows");
    BEGIN { $tests += 4; }
}

SCOPE: {
    is(newline_type(".$LF.$CR.") => "Mixed", "Mixed");
    is(newline_type(".$CR.$LF.") => "Mixed", "Mixed");
    is(newline_type(".$CRLF.$LF.") => "Mixed", "Mixed");
    is(newline_type(".$LF.$CRLF.") => "Mixed", "Mixed");
    is(newline_type(".$CR.$CRLF.") => "Mixed", "Mixed");
    is(newline_type(".$CRLF.$CR.") => "Mixed", "Mixed");
    is(newline_type(".$CR$LF$CR.") => "Mixed", "Mixed");
    is(newline_type(".$CR$LF$LF.") => "Mixed", "Mixed");
    BEGIN { $tests += 8; }
}

