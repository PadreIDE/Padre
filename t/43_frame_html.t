#!/usr/bin/perl

# Simple test script for testing HTML dialogs

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 1;
}

use t::lib::Padre;
use Padre::Wx::Frame::HTML ();

my $html = <<'END_HTML';
<html>
<body>
Hello World!
</body>
</html>
END_HTML

# Create a new dialog object, but don't show it
my $dialog = Padre::Wx::Frame::HTML->new(
	title => 'Test HTML Dialog',
	size  => [ 200, 200 ],
	html  => $html,
);
isa_ok( $dialog, 'Padre::Wx::Frame::HTML' );
