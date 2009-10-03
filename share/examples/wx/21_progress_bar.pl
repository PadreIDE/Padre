#!/usr/bin/perl
use strict;
use warnings;

#############################################################################
##
## Based on lib/Wx/DemoModules/wxProgressDialog.pm
## from the wxDemo ## written by Mattia Barbon
## Copyright:   (c) The Padre development team
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

use Wx qw(:progressdialog);
show_progress_bar();

sub show_progress_bar {
	my ($window) = @_;

	my $max = 20;

	my $dialog = Wx::ProgressDialog->new(
		'Progress dialog example',
		'An informative message',
		$max, $window,
		wxPD_CAN_ABORT | wxPD_AUTO_HIDE | wxPD_APP_MODAL | wxPD_ELAPSED_TIME | wxPD_ESTIMATED_TIME | wxPD_REMAINING_TIME
	);

	my $continue;
	foreach my $i ( 1 .. $max ) {
		sleep 1;
		if ( $i == $max ) {
			$continue = $dialog->Update( $i, "That's all, folks!" );
		} elsif ( $i == int( $max / 2 ) ) {
			$continue = $dialog->Update( $i, "Only a half left" );
		} else {
			$continue = $dialog->Update($i);
		}
		last unless $continue;
	}

	Wx::LogMessage(
		$continue
		? "Countdown from $max finished"
		: "Progress dialog aborted"
	);

	$dialog->Destroy;
}

