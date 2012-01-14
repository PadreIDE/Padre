#!/usr/bin/perl

use strict;
use warnings;

# Turn on $OUTPUT_AUTOFLUSH
$| = 1;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 14;
}

use Test::NoWarnings;
use t::lib::Padre;
use Padre::Wx;
use Padre;
use_ok('Padre::Wx::Panel::DebugOutput');

# Create the IDE
my $padre = new_ok('Padre');
my $main  = $padre->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );

# Create the breakpoints panel
my $panel = new_ok( 'Padre::Wx::Panel::DebugOutput', [$main] );


#######
# let's check our subs/methods.
#######
my @subs =
	qw( debug_output debug_status   
	view_close  view_icon  view_label  view_panel view_start view_stop );

use_ok( 'Padre::Wx::Panel::DebugOutput', @subs );

foreach my $subs (@subs) {
	can_ok( 'Padre::Wx::Panel::DebugOutput', $subs );
}

# done_testing();

1;

__END__
