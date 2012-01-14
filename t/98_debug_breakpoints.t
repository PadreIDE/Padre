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
	plan tests => 22;
}

use Test::NoWarnings;
use t::lib::Padre;
use Padre::Wx;
use Padre;
use_ok('Padre::Wx::Panel::Breakpoints');

# Create the IDE
my $padre = new_ok('Padre');
my $main  = $padre->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );

# Create the breakpoints panel
my $panel = new_ok( 'Padre::Wx::Panel::Breakpoints', [$main] );


#######
# let's check our subs/methods.
#######
my @subs =
	qw( _add_bp_db _delete_bp_db _setup_db _update_list on_delete_not_breakable_clicked
	on_delete_project_bp_clicked on_refresh_click on_set_breakpoints_clicked 
	on_show_project_click set_up   
	view_close  view_icon  view_label  view_panel view_start view_stop );

use_ok( 'Padre::Wx::Panel::Breakpoints', @subs );

foreach my $subs (@subs) {
	can_ok( 'Padre::Wx::Panel::Breakpoints', $subs );
}

# done_testing();

1;

__END__
