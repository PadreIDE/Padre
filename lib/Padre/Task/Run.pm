package Padre::Task::Run;

# Generic task for executing programs via system() and streaming
# their output back to the main program.

use 5.008005;
use strict;
use warnings;
use Params::Util ();
use Padre::Task  ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';

sub new {
	TRACE( $_[0] ) if DEBUG;
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Params and defaults
	$self->{timeout} ||= 10;
	unless ( Params::Util::_ARRAY( $self->{cmd} ) ) {
		die "Failed to provide command to execute";
	}

	return $self;
}

sub run {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Set up for execution
	require IPC::Run;
	my $timeout = IPC::Run::timeout( $self->{timeout} );
	my $stdin   = '';
	my $stdout  = '';
	my $stderr  = '';

	# Start the process and wait for output
	TRACE( "Running " . join( @{ $self->{cmd} } ) ) if DEBUG;
	my $handle = IPC::Run::start(
		$self->{cmd},
		\$stdin,
		\$stdout,
		\$stderr,
		$timeout,
	);

	# Wait for output and send them to the handlers
	local $@ = '';
	eval {
		while (1)
		{
			if ( $stdout =~ s/^(.*?)\n// ) {
				$self->stdout("$1");
				next;
			}
			$handle->pump;
		}
	};
	if ($@) {
		if ( $@ =~ /^process ended prematurely/ ) {

			# Normal exit
			TRACE("Process stopped normally") if DEBUG;
			$handle->kill_kill; # Just in case
			return 1;
		}

		# Otherwise, we probably hit the timeout
		TRACE("Process crashed ($@)") if DEBUG;
		$self->{errstr} = $@;
		$handle->kill_kill;
	}

	return 1;
}

# By default, stream STDOUT to the main window status bar.
# Any serious user of this task will want to do something different
# with the stdout and will override this method.
sub stdout {
	TRACE( $_[1] ) if DEBUG;
	my $self = shift;
	$self->tell_status( $_[0] );
	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
