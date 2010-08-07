#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	plan( tests => 2 );
}
use Test::NoWarnings;

require Padre::Document::Perl;

# Create the object so that Padre->ide works
#my $app = Padre->new;
#isa_ok( $app, 'Padre' );

SCOPE: {
	*_find_sub_decl_line_number=*Padre::Document::Perl::_find_sub_decl_line_number;
	my $code =<<'EOT';
	        line 0;
		sub test {
		}
EOT
	is(_find_sub_decl_line_number('test',$code),1);
}
