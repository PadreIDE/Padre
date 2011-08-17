#!/usr/bin/perl

use 5.006;
use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

plan( tests => 1 );
use Padre::Util;
use File::Basename ();
use File::Spec     ();
use FindBin;

# TODO: We need to pass the $main object to the create function
# and certain other things need to be in place before running
use Padre::Wx::Action;
use Padre::Wx::ActionLibrary;
sub Padre::ide { return bless {}, 'Padre::IDE'; }
sub Padre::IDE::actions { return {} }
sub Padre::IDE::config { return bless {}, 'Padre::Config' }
SKIP: {

	# TODO check if every action has a comment as required
	skip 'Fix this test!', 1;
	Padre::Wx::ActionLibrary->init( bless {}, 'Padre::IDE' );
	ok(1);
}
