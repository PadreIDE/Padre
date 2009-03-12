#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
	$| = 1; # flush for the threads
}

use Test::More tests => 50;
use threads;
use threads::shared;
use Padre::Task;
use lib '.';
use t::lib::Padre::Task::Test;

our $TestClass; # secret class name

sub fake_run_task {
	my $string = shift;
	my $recovered = Padre::Task->deserialize( \$string );
	ok(defined $recovered, "recovered form defined");
	isa_ok($recovered, 'Padre::Task');
	isa_ok($recovered, $TestClass);
	#is_deeply($recovered, $task);
	
	if (threads->tid() == 0) { # main thread
		ok( exists($recovered->{main_thread_only})
		    && not exists($recovered->{_main_thread_data_id}),
		    && $recovered->{main_thread_only} eq 'not in sub thread',
		    "main-thread data stays available in main thread" );
	}
	else {
		ok( not exists($recovered->{main_thread_only}),
		    && exists($recovered->{_main_thread_data_id}),
		    "main-thread data not available in worker thread" );
	}
	
	$recovered->run();
	$string = undef;
	$recovered->serialize(\$string);
	ok(defined $string);
	return $string;
}

sub fake_execute_task {
	my $class = shift;
	my $use_threads = shift;

	ok($class->can('new'), "task can be constructed");
	my $task = $class->new( main_thread_only => "not in sub thread" );
	isa_ok($task, 'Padre::Task');
	isa_ok($task, $class);
	ok($task->can('prepare'), "can prepare");
	
	$task->prepare();
	my $string;
	$task->serialize(\$string);
	ok(defined $string, "serialized form defined");

	if ($use_threads) {
		my $thread = threads->create(
			\&fake_run_task, $string
		);
		$string = $thread->join();
		# modify main thread copy of test counter since
		# it was copied for the worker thread.
		my $tb = Test::Builder->new();
		$tb->current_test( $tb->current_test() + 9 ); # XXX - watch out! Magic number of tests in thread
		isa_ok($thread, 'threads');
	}
	else {
		$string = fake_run_task($string);
		ok(1);
	}

	my $final = Padre::Task->deserialize( \$string );
	ok(defined $final);
	ok(not exists $task->{answer});
	$task->{answer} = 'succeed';
	is_deeply($final, $task);
	$final->finish();
}

package main;
$TestClass = "Padre::Task::Test";
fake_execute_task($TestClass, 0); # no threading
fake_execute_task($TestClass, 1); # threading




__END__

