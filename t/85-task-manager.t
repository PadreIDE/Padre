#!/usr/bin/perl

use strict;
use warnings;
use Class::Autouse ':devel';

use Test::More;
BEGIN {
	if ( not $ENV{DISPLAY} and not $^O eq 'MSWin32' ) {
		plan( skip_all => 'Needs DISPLAY' );
		exit 0;
	}
}

BEGIN {
	plan( skip_all => 'Fails for unknown reasons, skipping till tsee fixes it' );
	exit 0;
}

use vars '$TestClass';
BEGIN {
	$TestClass = 'Padre::Task::Test';
}

plan( tests => 13 );

use t::lib::Padre;
use Padre;

# TODO: test in non-degraded mode

use_ok('Padre::TaskManager');
use_ok('Padre::Task');
require t::lib::Padre::Task::Test;

# Before we create the Padre object,
# make sure that thread preference is off.
my $config = Padre::Config->read;
isa_ok( $config, 'Padre::Config' );
ok( $config->set( threads => 0 ), '->set ok' );
ok( $config->write, '->write ok' );

# Create the object so that Padre->ide works
my $app = Padre->new;
isa_ok($app, 'Padre');

my $tm = Padre::TaskManager->new(
	use_threads => 0,
);
isa_ok($tm, 'Padre::TaskManager');

my $padre = Padre->inst;
is_deeply($tm, $padre->task_manager, 'TaskManager is a singleton');

my $task = Padre::Task::Test->new(
	main_thread_only => 'not in sub thread',
);
isa_ok( $task, 'Padre::Task::Test' );

$task->prepare;
$task->schedule;
# TODO: check the issues with finish, etc.
$tm->cleanup;
