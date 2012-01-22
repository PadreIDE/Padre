package Padre::Breakpoints;

# This module is in entirely the wrong place

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

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

	if ( $#{ $debug_breakpoints->select("WHERE filename = \"$current_file\" AND line_number = \"$bp_line\"") } >= 0 ) {

		# say 'delete me';
		$editor->MarkerDelete( $bp_line - 1, Padre::Constant::MARKER_BREAKPOINT() );
		$editor->MarkerDelete( $bp_line - 1, Padre::Constant::MARKER_NOT_BREAKABLE() );
		$debug_breakpoints->delete("WHERE filename = \"$current_file\" AND line_number = \"$bp_line\"");
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

#TODO finish when in trunk
#######
# function show_breakpoints
# to be called when showing current file
#######
sub show_breakpoints {

	my $editor            = Padre::Current->editor;
	my $debug_breakpoints = ('Padre::DB::DebugBreakpoints');
	my $current_file      = $editor->{Document}->filename;
	my $sql_select        = "WHERE BY filename = \"$current_file\" ASC, line_number ASC";
	my @tuples            = $debug_breakpoints->select($sql_select);

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
