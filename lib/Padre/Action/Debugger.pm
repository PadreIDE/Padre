package Padre::Action::Debugger;

# Actions for debugging the current document

=pod

=head1 NAME

Padre::Action::Debugger is a outsourced module. It creates Actions for
various options to run the current file.

=cut

use 5.008;
use strict;
use warnings;
use Padre::Action ();
use Padre::Current qw{_CURRENT};
use Padre::Util ('_T');

our $VERSION = '0.53';

#####################################################################

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;


	Padre::Action->new(
		name         => 'debug.step_in',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-stop-after-command',
		label        => _T('Step In') . ' (&s) ',
		comment      => _T(
			'Execute the next statement, enter subroutine if needed. (Start debugging if it is not yet running)'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_step_in;
		},
	);

	Padre::Action->new(
		name         => 'debug.step_over',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-stop-after-procedure',
		label        => _T('Step Over') . ' (&n) ',
		comment      => _T(
			'Execute the next statement, If it is a subroutine call, stop only after it returned. (Start debugging if it is not yet running)'
		),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_step_over;
		},
	);


	Padre::Action->new(
		name         => 'debug.step_out',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-jump-back',
		label        => _T('Step Out') . ' (&r) ',
		comment      => _T('If withing a subroutine, run till return is called and then stop.'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_step_out;
		},
	);

	Padre::Action->new(
		name         => 'debug.run',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_tools-macro',
		label        => _T('Run till breakpoint') . ' (&c) ',
		comment      => _T('Start running and/or continoue running till next breakpoint or watch'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_run;
		},
	);

	Padre::Action->new(
		name         => 'debug.jump_to',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => _T('Jump to current execution line'),
		comment      => _T('Set focus to the line where the current statement is in the debugging process'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_jumpt_to;
		},
	);

	Padre::Action->new(
		name         => 'debug.set_breakpoint',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-insert-breakpoint',
		label        => _T('Set breakpoint') . ' (&b) ',
		comment      => _T('Set a breakpoint to the current location of the cursor with a condition'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_set_breakpoint;
		},
	);

	Padre::Action->new(
		name         => 'debug.remove_breakpoint',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => _T('Remove breakpoint'),
		comment      => _T('Remove the breakpoint at the current location of the cursor'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_remove_breakpoint;
		},
	);

	Padre::Action->new(
		name         => 'debug.list_breakpoints',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => _T('List all the breakpoints'),
		comment      => _T('List all the breakpoints on the console'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_list_breakpoints;
		},
	);

	Padre::Action->new(
		name         => 'debug.run_to_cursor',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => _T('Run to cursor'),
		comment      => _T('Set a breakpoint at the line where to cursor is and run till there'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_run_to_cursor;
		},
	);


	Padre::Action->new(
		name         => 'debug.show_stack_trace',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => _T('Show Stack Trace') . ' (&T) ',
		comment      => _T('When in a subroutine call show all the calls since the main of the program'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_show_stack_trace;
		},
	);

	Padre::Action->new(
		name         => 'debug.display_value',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-watch-variable',
		label        => _T('Display value'),
		comment      => _T('Display the current value of a variable in the right hand side debugger pane'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_display_value;
		},
	);

	Padre::Action->new(
		name         => 'debug.show_value',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => _T('Show Value') . ' (&x) ',
		comment      => _T('Show the value of a variable.'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_show_value;
		},
	);

	Padre::Action->new(
		name         => 'debug.evaluate_expression',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => _T('Evaluate Expression'),
		comment      => _T('Type in any expression and evaluate it in the debugged process'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_evaluate_expression;
		},
	);

	Padre::Action->new(
		name         => 'debug.quit',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'actions/stop',
		label        => _T('Quit Debugger') . ' (&q) ',
		comment      => _T('Quit the process being debugged'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_}->debug_perl_quit;
		},
	);



	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
