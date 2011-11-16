#!/usr/bin/perl

# Tests for the Padre::Delta module

use strict;
use warnings;
use Test::More tests => 5;
use Test::NoWarnings;
use t::lib::Padre;
use Padre::Delta;





######################################################################
# Null Delta

SCOPE: {
	my $null = Padre::Delta->new;
	isa_ok( $null, 'Padre::Delta' );
	ok( $null->null, '->null ok' );
}





######################################################################
# Creation from typical Algorithm::Diff output

SCOPE: {
	my $delta = Padre::Delta->from_diff(
		[
			[ '-', 8, 'use 5.008;' ],
			[ '+', 8, 'use 5.008005;' ],
			[ '+', 9, 'use utf8;' ],
		],
		[
			[ '-', 36, "\t\tWx::gettext(\"Set Bookmark\") . \":\"," ],
			[ '+', 37, "\t\tWx::gettext(\"Set Bookmark:\")," ],
		],
		[
			[ '-', 36, "\t\tWx::gettext(\"Existing Bookmark\") . \":\"," ],
			[ '+', 37, "\t\tWx::gettext(\"Existing Bookmark:\")," ],
		],
	);
	isa_ok( $delta, 'Padre::Delta' );
	ok( ! $delta->null, '->null false' );
}
