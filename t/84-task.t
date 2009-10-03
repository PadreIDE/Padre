#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	$| = 1; # Flush for the threads
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 108;
}
use t::lib::Padre;
use threads;         # need to be loaded before Padre
use threads::shared; # need to be loaded before Padre
use Padre::Task;
use t::lib::Padre::Task::Test;
use t::lib::Padre::Task::PPITest;

our $TestClass;      # secret Task class name accessible in the test threads. See also way below

# reminiscent of the in-thread worker loop in Padre::TaskManager:
sub fake_run_task {
	my $string = shift;

	# try to recover the serialized task from its Storable-dumped form to an object
	my $recovered = Padre::Task->deserialize( \$string );
	ok( defined $recovered, "recovered form defined" );
	isa_ok( $recovered, 'Padre::Task' );
	isa_ok( $recovered, $TestClass );   # a subcalss of Padre::Task

	if ( threads->tid() == 0 ) {        # main thread
		                                # Test the execution in the main thread in case worker threads are disabled
		ok( exists( $recovered->{main_thread_only} )
				&& ( not exists( $recovered->{_main_thread_data_id} ) )
				&& $recovered->{main_thread_only} eq 'not in sub thread',
			"main-thread data stays available in main thread"
		);
	} else {

		# Test the execution in a worker thread
		ok( ( not exists( $recovered->{main_thread_only} ) ) && exists( $recovered->{_main_thread_data_id} ),
			"main-thread data not available in worker thread"
		);
	}

	# call the test task's run method
	$recovered->run();
	$string = undef;

	# ship the thing back at the end
	$recovered->serialize( \$string );
	ok( defined $string );
	return $string;
}

# helper sub that runs a test task. Reminiscent of what the user would do
# plus what the scheduler does
sub fake_execute_task {
	my $class           = shift;
	my $test_spec       = shift;
	my $use_threads     = $test_spec->{threading};
	my $extra_data      = $test_spec->{extra_data} || {};
	my $tests_in_thread = $test_spec->{thread_tests} || 0;

	# normally user code:
	$class->new( text => 'foo' ); # FIXME necessary for the following to pass for Padre::Task::PPITest???
	ok( $class->can('new'), "task can be constructed" );
	my $task = $class->new( main_thread_only => "not in sub thread", %$extra_data );
	isa_ok( $task, 'Padre::Task' );
	isa_ok( $task, $class );
	ok( $task->can('prepare'), "can prepare" );

	# done by the scheduler:
	$task->prepare();
	my $string;
	$task->serialize( \$string );
	ok( defined $string, "serialized form defined" );

	if ($use_threads) {
		my $thread = threads->create( \&fake_run_task, $string );
		$string = $thread->join();

		# modify main thread copy of test counter since
		# it was copied for the worker thread.
		my $tb = Test::Builder->new();
		$tb->current_test( $tb->current_test() + $tests_in_thread ); # XXX - watch out! Magic number of tests in thread
		isa_ok( $thread, 'threads' );
	} else {
		$string = fake_run_task($string);
		ok(1);
	}

	# done by the scheduler:
	my $final = Padre::Task->deserialize( \$string );
	ok( defined $final );
	ok( not exists $task->{answer} );
	$task->{answer} = 'succeed';
	if ( $task->isa("Padre::Task::Test") ) {
		is_deeply( $final, $task );
	} else {
		pass("Skipping deep comparison for non-basic tasks");
	}
	$final->finish();
}

package main;

# simple task test
$TestClass = "Padre::Task::Test";
my $testspec = { threading => 0, thread_tests => 9, };
fake_execute_task( $TestClass, $testspec );
$testspec->{threading} = 1;
fake_execute_task( $TestClass, $testspec );

# PPI subtask test
$TestClass = "Padre::Task::PPITest";
$testspec->{thread_tests} = 11;
$testspec->{extra_data} = { text => q(my $self = shift;) };
$testspec->{threading} = 0;
fake_execute_task( $TestClass, $testspec );

$testspec->{threading} = 1;
fake_execute_task( $TestClass, $testspec );
