package Padre::Wx;

# Provides a set of Wx-specific miscellaneous functions

use 5.008;
use strict;
use warnings;

# Threading must be loaded before Wx loads
use threads;
use threads::shared;
use Thread::Queue 2.11;

# Load every exportable constant into here, so that they come into
# existence in the Wx:: packages, allowing everywhere else in the code to
# use them without braces.
use Wx         (':everything');
use Wx         ('wxTheClipboard');
use Wx::Event  (':everything');
use Wx::DND    ();
use Wx::STC    ();
use Wx::AUI    ();
use Wx::Locale ();

our $VERSION = '0.67';

# Hard version lock on a new-enough Wx.pm
BEGIN {
	unless ( $Wx::VERSION and $Wx::VERSION >= 0.91 ) {
		die("Your Wx.pm is not new enough (need 0.91, found $Wx::VERSION)");
	}
}





#####################################################################
# Defines for sidebar marker; others may be needed for breakpoint
# icons etc.

use constant {
	MarkError      => 1,
	MarkWarn       => 2,
	MarkLocation   => 3, # current location of the debugger
	MarkBreakpoint => 4, # location of the debugger breakpoint
};





#####################################################################
# Defines for object IDs

use constant {
	ID_TIMER_SYNTAX      => 30001,
	ID_TIMER_FILECHECK   => 30002,
	ID_TIMER_POSTINIT    => 30003,
	ID_TIMER_OUTLINE     => 30004,
	ID_TIMER_ACTIONQUEUE => 30005,
	ID_TIMER_LASTRESORT  => 30006,
	ID_TIMER_NTH         => 30007,
};





#####################################################################
# Convenience Functions

# Colour constructor
sub color {
	my $rgb = shift;
	my @c = ( 0xFF, 0xFF, 0xFF ); # Some default
	if ( not defined $rgb ) {

		# Carp::cluck("undefined color");
	} elsif ( $rgb =~ /^(..)(..)(..)$/ ) {
		@c = map { hex($_) } ( $1, $2, $3 );
	} else {

		# Carp::cluck("invalid color '$rgb'");
	}
	return Wx::Colour->new(@c);
}

# The Wx::AuiPaneInfo method-chaining API is stupid.
# This method provides a less insane way to create one.
sub aui_pane_info {
	my $class = shift;
	my $info  = Wx::AuiPaneInfo->new;
	while (@_) {
		my $method = shift;
		$info->$method(shift);
	}
	return $info;
}





#####################################################################
# External Website Integration

# Fire and forget background version of Wx::LaunchDefaultBrowser
sub LaunchDefaultBrowser {
	warn("Padre::Wx::LaunchDefaultBrowser is deprecated. Use launch_browser");
	launch_browser(@_);
}

sub launch_browser {
	require Padre::Task::LaunchDefaultBrowser;
	Padre::Task::LaunchDefaultBrowser->new(
		url => $_[0],
	)->schedule;
}

# Launch a "Live Support" window on Mibbit.com or other service
sub launch_irc {
	my $channel = shift;

	# Generate the (long) chat URL
	my $url = "http://padre.perlide.org/irc.html?channel=$channel";
	if ( my $locale = Padre->ide->config->locale ) {
		$url .= "&locale=$locale";
	}

	# Spawn a browser to show it
	launch_browser($url);

	return;
}

1;

=pod

=head1 NAME

Padre::Wx - Wx integration for Padre

=head1 DESCRIPTION

Support function library for Wx related things, and bootstrap logic for Wx integration.

Isolates any F<Wx.pm> twiddling away from the actual Padre implementation code.

Load every exportable constant, so that they come into
existence in the C<Wx::> packages, allowing everywhere else in the code to
use them without braces.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
