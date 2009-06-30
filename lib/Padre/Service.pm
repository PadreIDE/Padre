package Padre::Service;
use strict;
use warnings;

our @ISA = 'Padre::Task';

=pod

=cut



sub run {
	my ($self,$queue) = @_;
	
	my $tid = threads->tid;
	my $event  = $self->{service_event};
	$self->post_event(  $event , "$tid;ALIVE" );
	my $running = 1;
		
	while ( $running ) {
		$self->service_loop;
		next unless $queue->pending;
		
		my $incoming = $queue->peek(0);
		# Peek at the queue - for something addressed to us
		if ( $incoming =~ m{$tid;} ) {
			my $instruction = $queue->dequeue;
			my ($command) =  $instruction =~ m{^$tid;(HANGUP|TERMINATE)};
			if ( $command eq 'HANGUP' ) {
				$self->hangup;
				$running = 0;
			}
			elsif ( $command eq 'TERMINATE' ) {
				$self->terminate;
				$running = 0;
			}
			else { warn "Unrecognised command event $command"; }
		}
		
		
		#$self->post_event( $event , "$tid;ALIVE" );		
	}
	
	return $self->service_results;
}


sub hangup {
	my ($self) = @_;
	
}


sub terminate {
	my ($self) = @_;

}


{
my $i = 0;
sub service_loop {
	my ($self) = @_;
	my $tid = threads->tid;
	$self->task_print( "Service ($tid) Looped [$i]\n" );
	$i++;	
	sleep 1;
}
}

sub service_results {
	"Service Completed!";
}

1;
