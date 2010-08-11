#!/usr/bin/perl

# Spawn and then shut down the task worker object.
# Done in similar style to the task master to help encourage
# implementation similarity in the future.

use strict;
use warnings;
use Test::More;
use Test::Exception;


######################################################################
# This test requires a DISPLAY to run
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 24;
}

use Padre::TaskHandle ();
use Padre::Task::Eval ();
use Padre::Logger;

use_ok('Test::NoWarnings');




######################################################################
# Run a straight forwards eval task via a handle

SCOPE: {
	my $task = Padre::Task::Eval->new(
		prepare => '1 + 2',
		run     => '3 + 4',
		finish  => '5 + 6',
	);
	isa_ok( $task, 'Padre::Task::Eval' );
	is( $task->{prepare}, '1 + 2', '->{prepare} is false' );
	is( $task->{run},     '3 + 4', '->{run} is false' );
	is( $task->{finish},  '5 + 6', '->{finish} is false' );

	# Wrap a handle around it
	my $handle = Padre::TaskHandle->new($task);
	isa_ok( $handle,       'Padre::TaskHandle' );
	isa_ok( $handle->task, 'Padre::Task::Eval' );
	is( $handle->hid, 1, '->hid ok' );

	# Run the task
	is( $handle->prepare, 1,  '->prepare ok' );
	is( $task->{prepare}, 3,  '->{prepare} is true' );
	is( $handle->run,     1,  '->run ok' );
	is( $task->{run},     7,  '->{run} is true' );
	is( $handle->finish,  1,  '->finish ok' );
	is( $task->{finish},  11, '->{finish} is true' );
}





######################################################################
# Exceptions without a handle

SCOPE: {
	my $task = Padre::Task::Eval->new(
		prepare => 'die "foo";',
		run     => 'die "bar";',
		finish  => 'die "baz";',
	);
	isa_ok( $task, 'Padre::Task::Eval' );

	# Do they throw normal exceptions
	throws_ok( sub { $task->prepare }, qr/foo/ );
	throws_ok( sub { $task->run },     qr/bar/ );
	throws_ok( sub { $task->finish },  qr/baz/ );
}





######################################################################
# Repeat with the handle

SCOPE: {
	my $task = Padre::Task::Eval->new(
		prepare => 'die "foo";',
		run     => 'die "bar";',
		finish  => 'die "baz";',
	);
	my $handle = Padre::TaskHandle->new($task);
	isa_ok( $task,   'Padre::Task::Eval' );
	isa_ok( $handle, 'Padre::TaskHandle' );

	# Do they throw normal exceptions
	is( $handle->prepare, '', '->prepare ok' );
	is( $handle->run,     '', '->run ok' );
	is( $handle->finish,  '', '->finish ok' );
}
