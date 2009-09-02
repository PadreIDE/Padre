package Padre::Task;

=pod

=head1 NAME

Padre::Task - Padre Background Task API

=head1 SYNOPSIS

Create a subclass of Padre::Task which implements your background
task:

  package Padre::Task::Foo;
  
  use base 'Padre::Task';
  
  # This is run in the main thread before being handed
  # off to a worker (background) thread. The Wx GUI can be
  # polled for information here.
  # If you don't need it, just inherit the default no-op.
  sub prepare {
          my $self = shift;
          if ( condition_for_not_running_the_task ) {
                  return "BREAK";
          }
          
          return 1;
  }

  # This is run in a worker thread and may take a long-ish
  # time to finish. It must not touch the GUI, except through
  # Wx events. TODO: explain how this works
  sub run {
          my $self = shift;
          # Do something that takes a long time!
          # optionally print to the output window
          $self->print("Background thread says hi!\n");
          return 1;
  }

  # This is run in the main thread after the task is done.
  # It can update the GUI and do cleanup.
  # You don't have to implement this if you don't need it.
  sub finish {
          my $self = shift;
          my $main = shift;
          # cleanup!
          return 1;
  }
  
  1;

From your code, you can then use this new background task class as
follows. (C<new> and C<schedule> are inherited.)

  require Padre::Task::Foo;
  my $task = Padre::Task::Foo->new(some => 'data');
  $task->schedule; # hand off to the task manager

As a special case, any (arbitrarily nested and complex) data
structure you put into your object under
the magic C<main_thread_only> hash slot will not be passed
to the worker thread but become available again when C<finish>
is called in the main thread. You can use this to pass references
to GUI objects and similar things to the finish event handler
since these must not be accessed from worker threads.

=head1 DESCRIPTION

This is the base class of all background operations in Padre. The SYNOPSIS
explains the basic usage, but in a nutshell, you create a subclass, implement
your own custom C<run> method, create a new instance, and call C<schedule>
on it to run it in a worker thread. When the scheduler has a free worker
thread for your task, the following steps happen:

=over 2

=item The scheduler calls C<prepare> on your object.

=item If your prepare method returns the string 'break', all further processing
is stopped immediately.

=item The scheduler serializes your object with C<Storable>.

=item Your object is handed to the worker thread.

=item The thread deserializes the task object and calls C<run()> on it.

=item After C<run()> is done, the thread serializes the object again
and hands it back to the main thread.

=item In the main thread, the scheduler calls C<finish> on your
object with the Padre main window object as argument for cleanup.

=back

During all this time, the state of your task object is retained!
So anything you store in the task object while in the worker thread
is still there when C<finish> runs in the main thread. (Confer the
CAVEATS section below!)

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Storable     ();
use IO::Handle   ();
use IO::String   ();
use Scalar::Util ();
use Params::Util '_INSTANCE';

our $VERSION = '0.45';

# TODO: Why are there require?
require Padre;
require Padre::Wx;

BEGIN {

	# Hack IO::String to be a real IO::Handle
	unless ( IO::String->isa('IO::Handle') ) {
		@IO::String::ISA = qw{IO::Handle IO::Seekable};
	}
}

use Class::XSAccessor constructor => 'new';

# set up the stdout/stderr printing events
our $STDOUT_EVENT : shared = Wx::NewEventType();
our $STDERR_EVENT : shared = Wx::NewEventType();

=pod

=head2 new

C<Padre::Task> provides a basic constructor for you to
inherit. It simply stores all provided data in the internal
hash reference.

=head2 schedule

C<Padre::Task> implements the scheduling logic for your
subclass. Simply call the C<schedule> method to have your task
processed by the task manager.

Calling this multiple times will submit multiple jobs.

=cut

SCOPE: {
	my $events_initialized = 0;

	sub schedule {
		my $self = shift;
		if ( !$events_initialized ) {
			my $main = Padre->ide->wx->main;
			Wx::Event::EVT_COMMAND(
				$main,
				-1,
				$STDOUT_EVENT,
				\&_on_stdout,
			);
			Wx::Event::EVT_COMMAND(
				$main,
				-1,
				$STDERR_EVENT,
				\&_on_stderr,
			);
			$events_initialized = 1;
		}
		Padre->ide->task_manager->schedule($self);
	}
}

=pod

=head2 run

This is the method that'll be called in the worker thread.
You must implement this in your subclass.

You must not interact with the Wx GUI directly from the
worker thread. You may use Wx thread events only.
TODO: Experiment with this and document it.

=cut

sub run {
	my $self = shift;
	warn "This is Padre::Task->run(); Somebody didn't implement his background task's run() method!";
	return 1;
}

=pod

=head2 prepare

In case you need to set up things in the main thread,
you can implement a C<prepare> method which will be called
right before serialization for transfer to the assigned
worker thread.

If C<prepare> returns the string C<break> (case insensitive),
all further processing of the task will be stopped and neither
C<run> nor C<finish> will be called. Any other return values
are generally ignored.

You do not have to implement this method in the subclass.

=cut

sub prepare {
	my $self = shift;
	return 1;
}

=pod

=head2 finish

Quite likely, you need to actually use the results of your
background task somehow. Since you cannot directly
communicate with the Wx GUI from the worker thread,
this method is called from the main thread after the
task object has been transferred back to the main thread.

The first and only argument to C<finish> is the Padre
main window object.

You do not have to implement this method in the subclass.

=cut

sub finish {
	my $self = shift;
	return 1;
}

# Scope for main thread data storage
SCOPE: {
	my %MainThreadData;

	# this will serialize the object and do some magic as it happens
	# This is an INTERNAL method and subject to change
	sub serialize {
		my $self = shift;

		# The idea is to store the actual class of the object
		# in the object itself for serialization. It's not as bad as
		# it sounds. It just requires two things from the subclasses:
		# - The subclasses cannot override "deserialize" and thus
		#   probably not "serialize" either. But that shouldn't be
		#   a huge deal as there are the "prepare" and "finish" hooks
		#   for the user.
		# - The subclasses must not use the "_process_class" slot
		#   of the object. (Ohh...)

		# save the real object class for deserialization
		my $class = ref($self);
		if ( exists $self->{_process_class} ) {
			require Carp;
			Carp::croak(
				"The '_process_class' slot in a Padre::Task" . " object is reserved for usage by Padre::Task" );
		}

		$self->{_process_class} = $class;

		my $save_main_thread_data = ( threads->tid() == 0 and exists $self->{main_thread_only} );
		if ($save_main_thread_data) {
			my $id = "$self";
			$id .= '_' while exists $MainThreadData{$id};
			$MainThreadData{$id} = $self->{main_thread_only};
			$self->{_main_thread_data_id} = $id;
			delete $self->{main_thread_only};
		}

		# remove pesky dependency by explicitly
		# blessing into Padre::Task
		bless $self => 'Padre::Task';

		my $ret = $self->_serialize(@_);

		# cleanup
		delete $self->{_process_class};
		if ($save_main_thread_data) {
			$self->{main_thread_only} = $MainThreadData{ $self->{_main_thread_data_id} };
			delete $self->{_main_thread_data_id};
		}
		bless $self => $class;

		return $ret;
	}

	# this will deserialize the object and do some magic as it happens
	# This is an INTERNAL method and subject to change
	sub deserialize {
		my $class = shift;

		my $padretask = Padre::Task->_deserialize(@_);
		my $userclass = $padretask->{_process_class};
		delete $padretask->{_process_class};

		no strict 'refs'; ## no critic
		my $ref = \%{"${userclass}::"};
		use strict 'refs';
		my $loaded = exists $ref->{"ISA"};
		unless ( $loaded or eval("require $userclass;") ) { ## no critic
			require Carp;
			if ($@) {
				Carp::croak("Failed to load Padre::Task subclass '$userclass': $@");
			} else {
				Carp::croak("Failed to load Padre::Task subclass '$userclass': It did not return a true value.");
			}
		}

		# restore the main-thread-only data in the task
		if ( threads->tid == 0 and exists $padretask->{_main_thread_data_id} ) {
			my $id = $padretask->{_main_thread_data_id};
			$padretask->{main_thread_only} = $MainThreadData{$id};
			delete $padretask->{_main_thread_data_id};
			delete $MainThreadData{$id};
		}

		my $obj = bless $padretask => $userclass;

		# Xtra evil , let a subclass ducktype a hook here
		$obj->deserialize_hook if $obj->can('deserialize_hook');

		return $obj;
	}
}

# old Process::Storable internals
sub _serialize {
	my $self = shift;

	# Serialize to a named file (locking it)
	if ( defined $_[0] and !ref $_[0] and length $_[0] ) {
		return Storable::lock_nstore( $self, shift );
	}

	# Serialize to a string (via a handle)
	if ( Params::Util::_SCALAR0( $_[0] ) ) {
		my $string = shift;
		$$string = 'pst0' . Storable::nfreeze($self);
		return 1;
	}

	# Serialize to a generic handle
	if ( defined fileno( $_[0] ) ) {
		local $/ = undef;
		return Storable::nstore_fd( $self, shift );
	}

	# Serialize to an IO::Handle object
	if ( Params::Util::_INSTANCE( $_[0], 'IO::Handle' ) ) {
		my $string   = Storable::nfreeze($self);
		my $iohandle = shift;
		$iohandle->print('pst0')  or return;
		$iohandle->print($string) or return;
		return 1;
	}

	# We don't support anything else
	undef;
}

# old Process::Storable internals
sub _deserialize {
	my $class = shift;

	# Serialize from a named file (locking it)
	if ( defined $_[0] and !ref $_[0] and length $_[0] ) {
		return Storable::lock_retrieve(shift);
	}

	# Serialize from a string (via a handle)
	if ( Params::Util::_SCALAR0( $_[0] ) ) {
		my $string = shift;

		# Remove the magic header if it exists
		if ( substr( $$string, 0, 4 ) eq 'pst0' ) {
			substr( $$string, 0, 4, '' );
		}

		return Storable::thaw($$string);
	}

	# Serialize from a generic handle
	if ( defined fileno( $_[0] ) ) {
		return Storable::retrieve_fd(shift);
	}

	# Serialize from an IO::Handle object
	if ( Params::Util::_INSTANCE( $_[0], 'IO::Handle' ) ) {
		local $/ = undef;
		my $string = $_[0]->getline;

		# Remove the magic header if it exists
		if ( substr( $string, 0, 4 ) eq 'pst0' ) {
			substr( $string, 0, 4, '' );
		}

		return Storable::thaw($string);
	}

	# We don't support anything else
	undef;
}

# The main-thread stdout hook
sub _on_stdout {
	my ( $main, $event ) = @_;
	@_ = (); # hack to avoid "Scalars leaked"
	my $out = $main->output();
	$main->show_output(1);
	$out->style_neutral();
	$out->AppendText( $event->GetData );
	return ();
}

# The main-thread stderr hook
sub _on_stderr {
	my ( $main, $event ) = @_;
	@_ = (); # hack to avoid "Scalars leaked"
	my $out = $main->output();
	$main->show_output(1);
	$out->style_bad();
	$out->AppendText( $event->GetData );
	$out->style_neutral();
	return ();
}

=pod

=head2 task_print

  $task->task_print("Hi this is immediately sent to the Padre output window\n");

Sends an event to the main Padre thread and dispays a
message in the Padre output window.

=cut

sub task_print {
	my $self = shift;
	$self->post_event( $STDOUT_EVENT, join( "", @_ ) );
	return ();
}

=pod

=head2 task_warn

  $task->task_warn("Hi this is immediately sent to the Padre output window\n");

Sends an event to the main Padre thread and dispays a
message in the Padre output window with style C<bad>.

=cut

sub task_warn {
	my $self = shift;
	$self->post_event( $STDERR_EVENT, join( "", @_ ) );
	return ();
}

=pod

=head2 post_event

This method allows you to easily post a Wx event to the main
thread. First argument must be the event ID, second argument
the data you want to pass to the event handler.

For a complete example, please check the code of
C<Padre::Task::Example::WxEvent>.

You can set up a new event ID in your Padre::Task subclass
like this:

  our $FUN_EVENT_TYPE =  : shared = Wx::NewEventType();

Then you have to setup the event handler (for example in the
C<prepare()> method. This should happen in the main thread!

But watch out: You should not declare the same
handler multiple times.

  Wx::Event::EVT_COMMAND(
      Padre->ide->wx->main,
      -1,
      $FUN_EVENT,
      \&update_gui_with_fun
  );
  
  sub update_gui_with_fun {
      my ($main, $event) = @_; @_=(); # hack to avoid "Scalars leaked"
      my $data = $event->GetData();
  }
  
After that, you can dispatch events of type C<$FUN_EVENT_TYPE>
by simply running:

  $self->post_event($FUN_EVENT_TYPE, $data);

=cut

use Carp qw( cluck );

sub post_event {
	my ( $self, $eventid, $data ) = @_;
	@_ = ();
	cluck 'eventid is not defined' unless defined $eventid;
	cluck "eventid[$eventid] , no data to post"
		unless ( defined $data and length($data) );

	Wx::PostEvent(
		$Padre::TaskManager::_main,
		Wx::PlThreadEvent->new( -1, $eventid, $data ),
	);
	return ();
}

1;

=pod

=head1 NOTES AND CAVEATS

Since the task objects are transferred to the worker threads via
C<Storable::freeze()> / C<Storable::thaw()>, you cannot put any data
into the objects that cannot be serialized by C<Storable>. I<To the best
of my knowledge>, that includes filehandles and code references.

=head1 SEE ALSO

The management of worker threads is implemented in the L<Padre::TaskManager>
class.

The transfer of the objects to and from the worker threads is implemented
with L<Storable>.

=head1 AUTHOR

Steffen Mueller C<smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
