#!/usr/bin/perl

# Spawn and then shut down the task worker object.
# Done in similar style to the task master to help encourage
# implementation similarity in the future.

use strict;
use warnings;
use Test::More;


######################################################################
# This test requires a DISPLAY to run
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 41;
}
use Test::NoWarnings;
use Padre::TaskHandle     ();
use Padre::Task::Addition ();
use Padre::Logger;





######################################################################
# Check the raw task

SCOPE: {
	my $addition = Padre::Task::Addition->new(
		x => 2,
		y => 3,
	);
	isa_ok( $addition, 'Padre::Task::Addition' );
	is( $addition->{x}, 2,     '->{x} matches expected' );
	is( $addition->{y}, 3,     '->{y} matches expected' );
	is( $addition->{z}, undef, '->{z} matches expected' );

	# Run the task
	is( $addition->{prepare}, 0, '->{prepare} is false' );
	is( $addition->prepare,   1, '->prepare ok' );
	is( $addition->{prepare}, 1, '->{prepare} is true' );

	is( $addition->{run}, 0, '->{run} is false' );
	is( $addition->run,   1, '->run ok' );
	is( $addition->{run}, 1, '->{run} is true' );

	is( $addition->{finish}, 0, '->{finish} is false' );
	is( $addition->finish,   1, '->finish ok' );
	is( $addition->{finish}, 1, '->{finish} is true' );

	is( $addition->{x}, 2, '->{x} matches expected' );
	is( $addition->{y}, 3, '->{y} matches expected' );
	is( $addition->{z}, 5, '->{z} matches expected' );

	# Check task round-trip serialization
	my $string = $addition->as_string;
	ok( ( defined $string and !ref $string and length $string ),
		'->as_string ok',
	);
	my $round = Padre::Task::Addition->from_string($string);
	isa_ok( $round, 'Padre::Task::Addition' );
	is_deeply( $round, $addition, 'Task round-trips ok' );
}





######################################################################
# Run the task via a handle object

SCOPE: {
	my $task = Padre::Task::Addition->new( x => 2, y => 3 );
	my $handle = Padre::TaskHandle->new($task);
	isa_ok( $handle,       'Padre::TaskHandle' );
	isa_ok( $handle->task, 'Padre::Task::Addition' );
	is( $handle->hid,       1,     '->hid ok' );
	is( $handle->task->{x}, 2,     '->{x} matches expected' );
	is( $handle->task->{y}, 3,     '->{y} matches expected' );
	is( $handle->task->{z}, undef, '->{z} matches expected' );

	# Run the task
	is( $task->{prepare}, 0, '->{prepare} is false' );
	is( $handle->prepare, 1, '->prepare ok' );
	is( $task->{prepare}, 1, '->{prepare} is true' );

	is( $task->{run}, 0, '->{run} is false' );
	is( $handle->run, 1, '->run ok' );
	is( $task->{run}, 1, '->{run} is true' );

	is( $task->{finish}, 0, '->{finish} is false' );
	is( $handle->finish, 1, '->finish ok' );
	is( $task->{finish}, 1, '->{finish} is true' );

	is( $handle->task->{x}, 2, '->{x} matches expected' );
	is( $handle->task->{y}, 3, '->{y} matches expected' );
	is( $handle->task->{z}, 5, '->{z} matches expected' );

	# Check handle round-trip serialisation
	my $array = $handle->as_array;
	is( ref($array), 'ARRAY', '->as_array ok' );
	my $round = Padre::TaskHandle->from_array($array);
	isa_ok( $round, 'Padre::TaskHandle' );
	is_deeply( $round, $handle, 'Round trip serialisation ok' );
}
