#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
BEGIN {
	$| = 1; # flush for the threads
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	if ( $^O eq 'MSWin32' ) {
		plan skip_all => 'Windows currently has too many problems with this. Please fix!';
		exit(0);
	}
}
use threads;         # need to be loaded before Padre
use threads::shared; # need to be loaded before Padre
use t::lib::Padre;
use Padre::Service;

# secret Task class name accessible in the test threads. See also way below
our $TestClass;

# reminiscent of the in-thread worker loop in Padre::TaskManager:
sub fake_run_task {
	my $string = shift;
	my $spec   = shift;
	# try to recover the serialized task from its Storable-dumped form to an object
	my $recovered = Padre::Task->deserialize( \$string );

	ok(defined $recovered, "recovered form defined");
	isa_ok($recovered, 'Padre::Task');
	isa_ok($recovered, $TestClass); # a subcalss of Padre::Task
	#is_deeply($recovered, $task);
	
	# Test the execution in the main thread in case worker threads are disabled
	if (threads->tid() == 0) { # main thread
		ok( exists($recovered->{main_thread_only})
		    && (not exists($recovered->{_main_thread_data_id}))
		    && $recovered->{main_thread_only} eq 'not in sub thread',
		    "main-thread data stays available in main thread" );
	}
	# Test the execution in a worker thread
	else {
		ok( (not exists($recovered->{main_thread_only}))
		    && exists($recovered->{_main_thread_data_id}),
		    "main-thread data not available in worker thread" );
	}
	
	# call the test task's run method
	$recovered->run();
	$string = undef;
	# ship the thing back at the end
	$recovered->serialize(\$string);
	return $string;
}

# helper sub that runs a test task. Reminiscent of what the user would do
# plus what the scheduler does
sub fake_execute_task {
	my $class           = shift;
	my $test_spec       = shift;
	my $use_threads     = $test_spec->{threading};
	my $extra_data      = $test_spec->{extra_data}||{};
	my $tests_in_thread = $test_spec->{thread_tests}||0;
	my $tb = Test::Builder->new;
	# normally user code:
	$class->new(text => 'foo'); # FIXME necessary for the following to pass for Padre::Task::PPITest???
	ok($class->can('new'), "task can be constructed");
	my $task = $class->new( main_thread_only => "not in sub thread", %$extra_data );
	isa_ok($task, 'Padre::Task');
	isa_ok($task, $class);
	ok($task->can('prepare'), "can prepare");
	
	# done by the scheduler:
	$task->prepare();
	my $string;
	$task->serialize(\$string);
	ok(defined $string, "serialized form defined");

	if ($use_threads) {
		my $thread = threads->create(
			\&fake_run_task, $string, $test_spec
		);
		$string = $thread->join();
		$tb->current_test( $tb->current_test()+ $tests_in_thread);
		isa_ok($thread, 'threads');
	}
	else {
		$string = fake_run_task($string);
		$tb->current_test( $tb->current_test()+ $tests_in_thread);
		ok($string, 'Returned from unthreaded service !');;
	}

	# done by the scheduler:
	my $final = Padre::Task->deserialize( \$string );
	ok(defined $final);
	ok(not exists $task->{answer});

	TODO: { 
		local $TODO = 'Cleanup the shambolic references in ::Service de/serialize';
		is_deeply($final, $task);
	}
	
	$task->{answer} = 'succeed';
	$final->finish();
}

package main;

# simple service test
$TestClass = "Padre::Service";
my $testspec = { threading => 0, thread_tests => 11, };
fake_execute_task($TestClass, $testspec);

# threaded service test
$testspec->{threading} = 1;
$testspec->{thread_tests} += 4; # serializer/tests 
fake_execute_task($TestClass, $testspec);
done_testing();
=pod

# PPI subtask test
$TestClass = "Padre::Task::PPITest";
$testspec->{thread_tests} = 11;
$testspec->{extra_data} = {text => q(my $self = shift;)};
$testspec->{threading} = 0;
fake_execute_task($TestClass, $testspec);

$testspec->{threading} = 1;
fake_execute_task($TestClass, $testspec);

=cut
