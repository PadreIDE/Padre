package Padre::Service;
use strict;
use warnings;

our @ISA = 'Padre::Task';

our $VERSION = '0.38';

=pod

=head1 NAME

Padre::Service - API for non trivial Padre::Task

=head2 SYNOPSIS

  # Create your service, default implementation warns to output
  #  sleeps 1 second and loops over.
  my $service = Padre::Service->new( 
	main_thread_only => \&show_my_dialog,
  );
  $service->schedule;
  
  # Later
  $service->shutdown; # Your show_my_dialog will be called...,eventually

=head1 DESCRIPTION

Padre::Service extends L<Padre::Task> to provide a means to launch and 
control a long running background service, without blocking the editor.

=head2 EXTENDING

To extend this class, inherit it and implement C<service_loop> and preferabbly
C<hangup>

C<service_loop> should not block forever. If there is no work for the service to do
then return immediately, allowing the C<<Task->run>> loop to

  package Padre::Service::HTTPD
  use base qw( Padre::Service );
  
  sub prepare { # Build a dummy httpd.conf from $self , "BREAK" if error }
  
  sub service_start { # Launch httpd binary goodness, IPC::Run3 maybe? }
  
  sub service_shutdown { # Clean shutdown httpd binary }
  
  sub service_loop { # ->select($timeout) on your IPC handles }
  
  sub hangup { ->service_shutdown ?!?}
  
  sub terminate { # Stop everything, brutally }
  
  sub service_results { # Returned as the task return to Padre, }
  
=head1 METHODS

=head2 run

Overrides C<Padre::Task::run> providing a non-blocking loop around the
TaskManager to Service shared queue.
C<run> will call ->hangup or ->terminate on your service if instructed
by the main thread, otherwise C<service_loop> is called in void context
with no arguments B<IN A TIGHT LOOP>.

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
		# YUK - how about a dedicated queue per service
		# peek and poke went out in the dark ages didn't they
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
			elsif ( $command eq 'PING' ) {
				$self->post_event( $event , "$tid;ALIVE" );
			}
			else { 
				$self->task_warn( "$self : Unrecognised command event $command" 
				)
			}
		
		}
		
		
	}
	return;
}

=head2 hangup

Called on your service when the editor requests a hangup. Your service is obliged
to gracefully stop what it is doing and return from this method as soon as possible

=cut

sub hangup {
	my ($self) = @_;
	
}

=head2 terminate

Called on your service when TaskManager believes your service is hung or not
responding to a C<<->hangup>. Your service is obliged to B<IMMEDIATELY> stop
everything and to hell with the consequences. 

=cut

sub terminate {
	my ($self) = @_;

}


=head2 service_loop

Called in a loop while the service is believed to be running
The default implementation emits output to the editor and sleeps for a
second before returning control to the loop.

=cut

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

=head1 COPYRIGHT

Copyright 2009 The Padre develoment team as listed in Padre.pm

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

1;
