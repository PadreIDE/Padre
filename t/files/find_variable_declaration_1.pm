package Padre::TaskManager;

use strict;
use warnings;

our $VERSION = '0.20';

# According to Wx docs,
# this MUST be loaded before Wx,
# so this also happens in the script.
use threads;
use threads::shared;
use Thread::Queue;

require Padre;
use Padre::Task;
use Padre::Wx;
use Wx::Event qw(EVT_COMMAND EVT_CLOSE);

# This event is triggered by the worker thread main loop after
# finishing a task.
our $TASK_DONE_EVENT : shared = Wx::NewEventType;
# Timer to reap dead workers every N milliseconds
our $REAP_TIMER;
# You can instantiate this class only once.
our $SINGLETON;

sub schedule {
	my $self = shift;
	my $process = shift;
	if (not ref($process) or not $process->isa("Padre::Task")) {
		die "Invalid task scheduled!"; # TODO: grace
	}

	# cleanup old threads and refill the pool
	$self->reap();

	$process->prepare();

	my $string;
	$process->serialize(\$string);
	if ($self->use_threads) {
		$self->task_queue->enqueue( $string );
	}
	else {
		# TODO: Instead of this hack, consider
		# "reimplementing" the worker loop 
		# as a non-threading, non-queued, fake worker loop
		$self->task_queue->enqueue( $string );
		$self->task_queue->enqueue( "STOP" );
		worker_loop( Padre->ide->wx->main, $self );
	}

	return 1;
}

=pod

=head2 setup_workers

Create more workers if necessary. Called by C<reap> which
is called regularly by the reap timer, so users don't
typically need to call this.

=cut

sub setup_workers {
	my $self = shift;
	return if not $self->use_threads;

	@_=(); # avoid "Scalars leaked"
	my $main = Padre->ide->wx->main;


	# ensure minimum no. workers
	my $workers = $self->{workers};
	while (@$workers < $self->{min_no_workers}) {
		$self->_make_worker_thread($main);
	}

	# add workers to satisfy demand
	my $jobs_pending = $self->task_queue->pending();
        my $n_threads_to_kill; # fake
	if (@$workers < $self->{max_no_workers} and $jobs_pending > 2*@$workers) {
		my $target = int($jobs_pending/2);
		$target = $self->{max_no_workers} if $target > $self->{max_no_workers};
		$self->_make_worker_thread($main) for 1..($target-@$workers);
                $n_threads_to_kill *= 5;#fake
	}

	return 1;
}

=pod

=head2 reap

Check for worker threads that have exited and can be joined.
If there are more worker threads than the normal number and
they are idle, one worker thread (per C<reap> call) is
stopped.

This method is called regularly by the reap timer (see
the C<reap_interval> option to the constructor) and it's not
typically called by users.

=cut

sub reap {
	my $self = shift;
	return if not $self->use_threads;

	@_=(); # avoid "Scalars leaked"
	my $workers = $self->{workers};

	my @active_or_waiting;
	warn "No. worker threads before reaping: ".scalar (@$workers);

	foreach my $worker (@$workers) {
		if ($worker->thread->is_joinable) {
			my $tmp = $worker->thread->join;
		}
		else {
			push @active_or_waiting, $worker;
		}
	}
	$self->{workers} = \@active_or_waiting;
	warn "No. worker threads after reaping:  ".scalar (@$workers);

	# kill the no. of workers that aren't needed
	my $n_threads_to_kill =  @active_or_waiting - $self->{max_no_workers};
	$n_threads_to_kill = 0 if $n_threads_to_kill < 0;
	my $jobs_pending = $self->task_queue->pending();

	# slowly reduce the no. workers to the minimum
	$n_threads_to_kill++
	  if @active_or_waiting-$n_threads_to_kill > $self->{min_no_workers}
	  and $jobs_pending == 0;
	
	if ($n_threads_to_kill) {
		# my $target_n_threads = @active_or_waiting - $n_threads_to_kill;
		my $queue = $self->task_queue;
		$queue->insert( 0, ("STOP") x $n_threads_to_kill )
		  unless $queue->pending() and not ref($queue->peek(0));

		# We don't actually need to wait for the soon-to-be-joinable threads
		# since reap should be called regularly.
		#while (threads->list(threads::running) >= $target_n_threads) {
		#  $_->join for threads->list(threads::joinable);
		#}
	}

	$self->setup_workers;

	return 1;
}
