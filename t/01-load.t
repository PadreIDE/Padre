#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;

	# Twice to avoid a warning
	$DB::single = $DB::single = 1;
}

use Test::NeedsDisplay;
use Test::More tests => 12;

use Class::Autouse ':devel';

ok( $] >= 5.008, 'Perl version is new enough' );

use_ok( 'Wx'                             );
diag "Wx Version: $Wx::VERSION " . Wx::wxVERSION_STRING();

use_ok( 't::lib::Padre'                  );
use_ok( 'Padre::Util'                    );
use_ok( 'Padre::Config'                  );
use_ok( 'Padre::DB'                      );
use_ok( 'Padre::Project'                 );
use_ok( 'Padre::Wx'                      );
use_ok( 'Padre::Wx::History::TextDialog' );
use_ok( 'Padre'                          );
use_ok( 'Padre::Pod2HTML'                );
use_ok( 'Padre::Pod::Viewer'             );
