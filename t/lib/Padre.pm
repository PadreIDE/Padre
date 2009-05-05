package t::lib::Padre;

# Common testing logic for Padre

use strict;
use warnings;
use Scalar::Util ();
use File::Temp   ();
use Exporter     ();
use Test::More   ();

our $VERSION = '0.20';
our @ISA     = 'Exporter';
our @EXPORT  = 'refis';

# By default, load Padre in a controlled environment
BEGIN {
	$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
}

# Test that two params are the same reference
sub refis {
	my $left  = Scalar::Util::refaddr(shift);
	my $right = Scalar::Util::refaddr(shift);
	my $name  = shift || 'References are the same';
	unless ( $left ) {
		Test::More::fail( $name );
		Test::More::diag("First argument is not a reference");
		return;
	}
	unless ( $right ) {
		Test::More::fail( $name );
		Test::More::diag("Second argument is not a reference");
		return;
	}
	Test::More::is( $left, $right, $name );		
}

# delay is counted from the previous event
sub setup_event {
	my ($frame, $events, $cnt) = @_;
	return if $cnt >= @$events;
	my $event = $events->[$cnt];

	if ($event->{subevents}) {
		setup_event($frame, $event->{subevents}, 0);
	}
	my $id    = Wx::NewId();
	my $timer = Wx::Timer->new( $frame, $id );
	Wx::Event::EVT_TIMER(
		$frame,
		$id,
		sub { $event->{code}->(@_); setup_event($frame, $events, $cnt+1) },
	);
	$timer->Start( $event->{delay}, 1 );
}

1;
