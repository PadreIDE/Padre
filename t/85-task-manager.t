#!/usr/bin/perl

use strict;
use warnings;

use FindBin      qw($Bin);
use File::Spec   ();
use Data::Dumper qw(Dumper);

use Test::More tests => 12;

use t::lib::Padre;
use Padre;

use vars '$TestClass';

# TODO: test in non-degraded mode

use_ok('Padre::TaskManager');
use_ok('Padre::Task');
require t::lib::Padre::Task::Test;

my $tm = Padre::TaskManager->new(use_threads => 0);
isa_ok($tm, 'Padre::TaskManager');
my $padre = Padre->inst();
is_deeply($tm, $padre->task_manager, 'TaskManager is a singleton');

$TestClass = 'Padre::Task::Test';
my $task = Padre::Task::Test->new( main_thread_only => 'not in sub thread' );
$task->prepare();
$task->schedule();
# TODO: check the issues with finish, etc.

$tm->cleanup();


