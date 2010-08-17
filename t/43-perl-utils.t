#!/usr/bin/perl

use strict;
use warnings;
use Test::More;


BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}

	plan( tests => 5 );
}
use Test::NoWarnings;

# badcode was complaining it was missing
# in truth, this test doesn't appear to need padre
# to run, but it's either add this to satisfy the xt/badcode.t
# test or add it to the %SKIP, which makes even less sense.
use t::lib::Padre;
require Padre::Document::Perl;

# Create the object so that Padre->ide works
#my $app = Padre->new;
#isa_ok( $app, 'Padre' );

*_find_sub_decl_line_number = *Padre::Document::Perl::_find_sub_decl_line_number;

SCOPE: {
	my $code = <<'EOT';
	        line 0;
		sub test {
		}
EOT
	is( _find_sub_decl_line_number( 'test', $code ), 1 );
}

SCOPE: {
	my $code = <<'EOT';
	        line 0;
	        sub test;
		sub test {
		}
EOT
	is( _find_sub_decl_line_number( 'test', $code ), 2 );
}
SCOPE: {
	my $code = <<'EOT';
	        line 0;
	        sub test($;$@);
		sub test {
		}
EOT
	is( _find_sub_decl_line_number( 'test', $code ), 2 );
}
SCOPE: {
	my $code = <<'EOT';
	        line 0;
	        sub test($;$@);
		sub test($;$@) {
		}
EOT
	is( _find_sub_decl_line_number( 'test', $code ), 2 );
}
