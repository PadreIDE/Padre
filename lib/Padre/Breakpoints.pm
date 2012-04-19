package Padre::Breakpoints;

#ToDo Q is this package wrong in the wronge location

use 5.008;
use strict;
use warnings;

our $VERSION = '0.96';

#######
# function set_breakpoints_clicked
# this is a toggle function based on current status
#######
sub set_breakpoints_clicked {

	my $debug_breakpoints = ('Padre::DB::DebugBreakpoints');

	my $editor       = Padre::Current->editor;
	my $current_file = $editor->{Document}->filename;
	my $bp_line      = $editor->GetCurrentLine + 1;
	my %bp_action;
	$bp_action{line} = $bp_line;

	if ( $#{ $debug_breakpoints->select( "WHERE filename = ? AND line_number = ?", $current_file, $bp_line ) } >= 0 ) {

		# say 'delete me';
		$editor->MarkerDelete( $bp_line - 1, Padre::Constant::MARKER_BREAKPOINT() );
		$editor->MarkerDelete( $bp_line - 1, Padre::Constant::MARKER_NOT_BREAKABLE() );
		$debug_breakpoints->delete_where( "filename = ? AND line_number = ?", $current_file, $bp_line );
		$bp_action{action} = 'delete';
	} else {

		# say 'create me';
		$editor->MarkerAdd( $bp_line - 1, Padre::Constant::MARKER_BREAKPOINT() );
		$debug_breakpoints->create(
			filename    => $current_file,
			line_number => $bp_line,
			active      => 1,
			last_used   => time(),
		);
		$bp_action{action} = 'add';
	}

	return \%bp_action;
}

#######
# function show_breakpoints
# to be called when showing current file
#######
sub show_breakpoints {

	my $editor            = Padre::Current->editor;
	my $debug_breakpoints = ('Padre::DB::DebugBreakpoints');
	my $current_file      = $editor->{Document}->filename;
	my $sql_select        = "WHERE filename = ? ORDER BY line_number ASC";
	my @tuples            = eval { $debug_breakpoints->select( $sql_select, $current_file ); };
	if ($@) {
		return;
	}

	for ( 0 .. $#tuples ) {

		if ( $tuples[$_][3] == 1 ) {
			$editor->MarkerAdd( $tuples[$_][2] - 1, Padre::Constant::MARKER_BREAKPOINT() );
		} else {
			$editor->MarkerAdd( $tuples[$_][2] - 1, Padre::Constant::MARKER_NOT_BREAKABLE() );
		}
	}
	return;
}


1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
