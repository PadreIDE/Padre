#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;

	# Twice to avoid a warning
	$DB::single = $DB::single = 1;
}

use Test::NeedsDisplay;
use Test::More tests => 19;
use Test::NoWarnings;
use Class::Autouse ':devel';

ok( $] >= 5.008, 'Perl version is new enough' );

use_ok( 'Wx'                             );
diag( "Tests find Wx: $Wx::VERSION " . Wx::wxVERSION_STRING() );
use_ok( 't::lib::Padre'                  );
use_ok( 'Padre::Util'                    );
use_ok( 'Padre::Config'                  );
use_ok( 'Padre::DB'                      );
use_ok( 'Padre::Project'                 );
use_ok( 'Padre::Wx'                      );
use_ok( 'Padre::Wx::HtmlWindow'          );
use_ok( 'Padre::Wx::Printout'            );
use_ok( 'Padre::Wx::History::TextDialog' );
use_ok( 'Padre::Wx::History::ComboBox'   );
use_ok( 'Padre'                          );
use_ok( 'Padre::Pod2HTML'                );
use_ok( 'Padre::Pod::Viewer'             );
use_ok( 'Padre::Plugin::Devel'           );
use_ok( 'Padre::Plugin::My'              );
