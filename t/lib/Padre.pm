package t::lib::Padre;

# Common testing logic for Padre

use strict;
use warnings;
use File::Temp;

# By default, load Padre in a controlled environment
BEGIN {
    $ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
}

# delay is counted from the previous event
sub setup_events {
	my ($frame, $events) = @_;
	my $delay = 0;
	foreach my $event (@$events) {
		my $id    = Wx::NewId();
		my $timer = Wx::Timer->new( $frame, $id );
		Wx::Event::EVT_TIMER(
			$frame,
			$id,
			$event->{code}
		);
		$delay += $event->{delay};
		$timer->Start( $delay, 1 );
	}
}

1;
