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
	plan tests => 54;
	use_ok( 'Debug::Client'   ,'0.16');
}

use Test::NoWarnings;
use t::lib::Padre;
use Padre::Wx;
use Padre;
use_ok('Padre::Wx::Panel::Debugger');

# Create the IDE
my $padre = new_ok('Padre');
my $main  = $padre->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );

# Create the debugger panel
my $panel = new_ok( 'Padre::Wx::Panel::Debugger', [$main] );


######
# let's check our subs/methods.
######

my @subs =
	qw( _bp_autoload  _debug_get_variable  _display_trace  _get_bp_db  _output_variables  
	_set_debugger  _setup_db  debug_perl  debug_perl_show_value  debug_quit  debug_run_till  
	debug_step_in  debug_step_out  debug_step_over  display_value  get_global_variables  
	get_local_variables on_all_threads_clicked  on_debug_clicked  
	on_display_options_clicked  on_display_value_clicked  on_dot_clicked  on_evaluate_expression_clicked  
	on_list_action_clicked  on_module_versions_clicked  on_quit_debugger_clicked  
	on_raw_clicked  on_run_till_clicked  on_running_bp_clicked  on_show_global_variables_checked  
	on_show_local_variables_checked  on_stacktrace_clicked  on_step_in_clicked  
	on_step_out_clicked  on_step_over_clicked  on_sub_names_clicked  on_trace_checked  
	on_view_around_clicked  on_watchpoints_clicked  quit  running  set_up  update_variables  
	view_close  view_icon  view_label  view_panel );

use_ok( 'Padre::Wx::Panel::Debugger', @subs );

foreach my $subs (@subs) {
	can_ok( 'Padre::Wx::Panel::Debugger', $subs );
}

# done_testing();

1;

__END__
