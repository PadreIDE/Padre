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
