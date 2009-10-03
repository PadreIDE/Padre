#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan( skip_all => 'Needs DISPLAY' );
		exit 0;
	}
	plan( tests => 18 );
}

# This must exist and must be global.
# It is examined by the code inside the test task.
our $TestClass = 'Padre::Task::Test';

# Need to load these before padre!
use threads;
use threads::shared;
use t::lib::Padre;
use Padre;

# TODO: test in non-degraded mode

use_ok('Padre::TaskManager');
use_ok('Padre::Task');
use_ok('Padre::Service');
require t::lib::Padre::Task::Test;

# Before we create the Padre object,
# make sure that thread preference is off.
my $config = Padre::Config->read;
isa_ok( $config, 'Padre::Config' );
ok( $config->set( threads => 0 ), '->set ok' );
ok( $config->write, '->write ok' );

# Create the object so that Padre->ide works
my $app = Padre->new;
isa_ok( $app, 'Padre' );

my $task_manager = Padre::TaskManager->new(
	use_threads => 0,
);
isa_ok( $task_manager, 'Padre::TaskManager' );

my $padre = Padre->ide;
is_deeply(
	$task_manager,
	$padre->task_manager,
	'TaskManager is a singleton',
);

my $task = Padre::Task::Test->new(
	main_thread_only => 'not in sub thread',
);
isa_ok( $task, 'Padre::Task::Test' );

$task->prepare;
$task->schedule;

# TODO: check the issues with finish, etc.
$task_manager->cleanup;
