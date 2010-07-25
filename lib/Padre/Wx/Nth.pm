package Padre::Wx::Nth;

# Provides rules and functionality to be triggered on a particular
# numbered startup of Padre.

use strict;
use warnings;

our $VERSION = '0.66';

# Even if more than one rule matches, only ever bother the user once.
sub nth {
	my $class = shift;
	my $main  = shift;
	my $nth   = shift;

	# Is it Padre's birthday
	my @t = localtime time;
	if ( $t[4] == 6 and $t[3] == 20 ) {
		my $rv = $main->yes_no(
			"Today is Padre's Birthday!\n" .
			"Would you like join the party and thank the developers?",
			"OMG!",
		);
		$main->action('help.live_support') if $rv;
		return 1;
	}

	# Nothing to say
	return 1;
}

1;
