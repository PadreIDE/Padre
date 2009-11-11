package Padre::Service;

use 5.008;
use strict;
use warnings;
use Carp qw( croak );

use threads;
use threads::shared;

use Padre::Wx     ();
use Padre::Task   ();
use Thread::Queue ();
our @ISA = 'Padre::Task';

our $VERSION = '0.50';

=pod

=head1 NAME

Padre::Service - persistent Padre::Task API

=head2 SYNOPSIS

  # Create your service, default implementation warns to output
  #  sleeps 1 second and loops over.
  my $service = Padre::Service->new();
  Wx::Event::EVT_COMMAND(
	$main , -1 , $service->event ,
	\&receive_data_from_service
  );
  $service->schedule;
  $service->


  # Later
  $service->shutdown; # Your show_my_dialog will be called...,eventually

=head1 DESCRIPTION

Padre::Service extends L<Padre::Task> to provide a means to launch and
control a long running background service, without blocking the editor.

=head2 EXTENDING

To extend this class, inherit it and implement C<service_loop> and preferably
C<hangup>.

C<service_loop> should not block forever. If there is no work for the service to do
then return immediately, allowing the C<< Task->run >> loop to continue.

  package Padre::Service::HTTPD
  use base qw( Padre::Service );

  sub prepare { # Build a dummy httpd.conf from $self , "BREAK" if error }

  sub service_start { # Launch httpd binary goodness, IPC::Run3 maybe? }

  sub service_shutdown { # Clean shutdown httpd binary }

  sub service_loop { # ->select($timeout) on your IPC handles }

  sub hangup { ->service_shutdown ?!?}

  sub terminate { # Stop everything, brutally }

=head1 METHODS

=head2 run

Overrides C<Padre::Task::run> providing a non-blocking loop around the
C<TaskManager> to C<Service> shared queue.

C<run> will call C<hangup> or C<terminate> on your service if instructed
by the main thread, otherwise C<service_loop> is called in void context
with no arguments B<in a tight loop>.

=cut

{
	my $running = 0;
	sub running {$running}

	sub stop  { $running = 0 }
	sub start { $running = 1 }; #??

	sub run {
		croak "Already running!" if $running;

		my ($self) = @_;
		my $queue = $self->queue;
		Padre::Util::debug("Running queue $queue");
		my $tid   = threads->tid;
		my $event = $self->event;

		# Now we're in the worker thread, start our service
		# and begin the select orbit around the manager's queue
		#  , the service_loop and throwing ->event back at the main thread
		$self->start;
		$running = 1;
		$self->post_event( $event, "ALIVE" );
		while ($running) {

			# Let the service provider have first chance.
			#   and if nothing is waiting in the queue - tight loop.
			$self->service_loop;
			next unless $queue->pending;

			my $command = $queue->dequeue;
			Padre::Util::debug("Service dequeued input");

			# Respond to HANGUP TERMINATE and PING -
			if ( ref($command) ) {
				$self->service_loop($command);
			}

			# Or possibly a signal from the main thread
			else {
				Padre::Util::debug("Caught command signal '$command'");
				if ( $command eq 'HANGUP' ) {
					$self->hangup( \$running );
				} elsif ( $command eq 'TERMINATE' ) {
					$self->terminate( \$running );
				} elsif ( $command eq 'PING' ) {
					$self->post_event( $event, "ALIVE" );
				} else {
					Padre::Util::debug("Service does not recognise '$command' signal");
				}
			}
		}

		# Loop broken - cleanup
		#$self->shutdown;
		return;
	}

}

=head2 start

consider start the background_thread analog of C<prepare> and will be called
in the service thread immediately prior to the service loop starting.


=cut

=head2 hangup

Called on your service when the editor requests a hangup. Your service is obliged
to gracefully stop what it is doing and return from this method as soon as possible

=cut

sub hangup {
	my ( $self, $running ) = @_;
	$$running = 0;
}

=head2 terminate

Called on your service when C<TaskManager> believes your service is hung or not
responding to a C<<->hangup>. Your service is obliged to B<IMMEDIATELY> stop
everything and to hell with the consequences.

=cut

sub terminate {
	my ( $self, $running ) = @_;
	$$running = 0;
}

=head2 service_loop

Called in a loop while the service is believed to be running
The default implementation emits output to the editor and sleeps for a
second before returning control to the loop.

=cut

{

	sub service_loop {
		my ( $self, $incoming ) = @_;
		$self->{iterator} = 0
			unless exists $self->{iterator};
		my $tid = threads->tid;
		$self->task_print('ok - entered service loop')
			|| print "ok - entered service loop\n";

		$self->task_print("# Service ($tid) Looped $self->{iterator}\n");
		if ( defined $incoming ) {
			$self->task_print("ok - got incoming service data '$incoming'");
		}

		# Tell the main thread some progress.
		$self->post_event( $self->event, "$self->{iterator}" );

		$self->{iterator}++;
		$self->tell('HANGUP') if $self->{iterator} > 10;
		sleep 1;
	}
}

=head2 event

Accessor for this service's instance event, in the running service
data may be posted to this event and the Wx subscribers will be notified

=cut

{
	our %ServiceEvents : shared = ();

	sub event {
		my $self = shift;
		if ( exists $ServiceEvents{ $self->{__service_refid} } ) {
			return $ServiceEvents{ $self->{__service_refid} };
		} else {
			croak "Cannot lookup shared event for $self";
		}
	}

	my %Queues : shared;

	sub prepare {
		my $self = shift;
		my $queue : shared;
		$queue           = new Thread::Queue;
		$Queues{"$self"} = $queue;
		$self->{_refid}  = "$self";
		$self->SUPER::prepare(@_);
	}

=head2 queue

accessor for the shared queue the service thread is polling for input.
Calling C<enqueue> on reference sends data to the service thread. L<Storable>
serialization rules apply. See also L<"event"> for receiving data from
the service thread

=cut

	sub queue {
		my $self = shift;
		if (   exists $self->{_refid}
			&& exists $Queues{ $self->{_refid} } )
		{
			return $Queues{ $self->{_refid} };
		} elsif ( exists $Queues{"$self"} ) {
			return $Queues{"$self"};
		} else {
			croak "No such service queue ";
		}

	}

	sub serialize {
		my $self = shift;

		#	croak "Serialized!!";
		my $service_refid = "$self";
		$self->{__service_refid} = $service_refid;

		# Wait until the last moment before we declare
		# the event
		my $service_event : shared = Wx::NewEventType;
		$ServiceEvents{$service_refid} = $service_event;

		#  	my $wx_attach;
		#  	if ( exists $self->{_main_thread_only}
		#	     &&
		#	     _INSTANCE( $self->{_main_thread_only}, 'Wx::Object' )
		#	    )
		#	{
		#		$wx_attach = $self->{_main_thread_only};
		#	}
		#	else {  $wx_attach = Padre->ide->wx->main };

		#	if (!exists $self->{__events_init}
		#	    and !defined $self->{__events_init} )
		#	{
		#		$self->{__events_init} =
		#		    Wx::Event::EVT_COMMAND(
		#			$wx_attach, -1,
		#			$service_event,
		#			sub{ $self->receive(@_) } ,
		#		);
		#	}

		# FILO
		my $payload = $self->SUPER::serialize(@_);

		return $payload;
	}

	sub deserialize_hook {
		my $self = shift;

		# FILO
		# Shutdown the queue and event ?;
	}

}

sub shutdown {
	my $self = shift;
	Padre::Util::debug("shutdown - $self");
	my $queue = $self->queue;
	$queue->enqueue('HANGUP');
}

sub cleanup {
	my $self = shift;
	Padre::Util::debug("cleanup - $self");
}

=head2 tell

Accepts a reference as it's argument, this is serialized and sent to
the service thread

=cut

## MAIN
sub tell {
	my ( $self, $ref ) = @_;
	my $queue = $self->queue;
	$queue->enqueue($ref);
}

=head1 COPYRIGHT

Copyright 2009 The Padre development team as listed in Padre.pm

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

1;
