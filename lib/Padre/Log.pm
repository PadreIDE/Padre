package Padre::Log;
use strict;
use warnings;

our $VERSION = '0.43';

use Carp  ();
use POSIX ();
use Class::XSAccessor::Array predicates => {
	is_debug     => 0,
	is_info      => 1,
	is_warn      => 2,
	is_error     => 3,
	is_fatal     => 4,
	is_trace     => 5,
	has_filename => 10,
	},
	getters => {
	get_filename => 10,
	},
	setters => {
	set_filename => 10,
	_set_trace   => 5,
	},
	;

sub new {
	my ( $class, %params ) = (@_);
	return unless $class;
	my $self = bless [], $class;

	$self->set_log_level( $params{'level'} );

	if ( $params{'filename'} ) {
		$self->set_filename( $params{'filename'} );
	}

	if ( $params{'trace'} ) {
		$self->enable_trace;
	} else {
		$self->disable_trace;
	}
	return $self;
}

sub enable_trace  { shift->_set_trace(1) }
sub disable_trace { shift->_set_trace(undef) }

sub set_log_level {
	my $self         = shift;
	my $level        = lc(shift);
	my %level_id_for = (
		'debug' => 0,
		'info'  => 1,
		'warn'  => 2,
		'error' => 3,
		'fatal' => 4,
		'off'   => 5,
	);

	if ( $level && defined $level_id_for{$level} ) {
		$level = $level_id_for{$level};
	} else {
		$level = $level_id_for{'warn'};
	}

	foreach my $i ( keys %level_id_for ) {
		if ( $level <= $level_id_for{$i} ) {
			${$self}[ $level_id_for{$i} ] = 1;
		} else {
			${$self}[ $level_id_for{$i} ] = undef;
		}
	}
}

######################################
## logging methods:

sub debug {
	my $self = shift;
	if ( $self->is_debug ) {
		$self->_log( 'debug', @_ );
	}
}

sub info {
	my $self = shift;
	if ( $self->is_info ) {
		$self->_log( 'info', @_ );
	}
}

sub warn {
	my $self = shift;
	if ( $self->is_warn ) {
		$self->_log( 'warn', @_ );
	}
}

sub error {
	my $self = shift;
	if ( $self->is_error ) {
		$self->_log( 'error', @_ );
	}
}

sub fatal {
	my $self = shift;
	if ( $self->is_fatal ) {
		$self->_log( 'fatal', @_ );
	}
}

sub _log {
	my $self    = shift;
	my $level   = uc(shift);
	my $message = join ' ', @_;
	my ( $package, $filename, $line ) = caller;

	# get file handle
	my $handle = \*STDERR;
	if ( $self->has_filename ) {
		open $handle, '>>', $self->get_filename
			or do {
			syswrite STDERR, "could not open file '$handle': $!\n";
			return;
			};
	}

	#log received message
	syswrite $handle, POSIX::strftime( "%H:%M:%S", localtime() ) . " $level [$package] line $line - @_\n"
		or syswrite STDERR, "could not write to handle: $!\n";

	if ( $self->is_trace ) {
		syswrite STDERR, Carp::longmess() . "\n";
	}
}

42;
__END__

=head1 NAME

Padre::Log - Simple logger for Padre



=head1 SYNOPSIS

While working inside Padre, what you probably want is:

	my $main = Padre->wx->ide->main; # you most likely already have
				   # one of those in your sub

	my $log = $main->log;

	$log->debug('now *there* is your problem!');
	$log->info('here I am');
	$log->warn('Danger! Danger!');
	$log->error('This shouldn't have happened');
	$log->fatal("Argh, I'm dead");

	if ( $log->is_debug() ) {
		$log->debug("add expensive @debugging over here")
	}



=head1 DESCRIPTION

This module provides a simple mechanism to log messages within Padre.
Padre developers are encouraged to use this along the code.



=head1 HOW TO USE IT

The Padre logging system is set via Padre's configuration file,
config.yml:

	log: 1
	log_level: 'debug'
	log_trace: 0
	log_filename: undef

But you should select these options directly via the 'Padre Developer
Tools' Plugin that comes bundled with Padre.


=head2 Log Levels

There are five predefined log levels: C<debug>, C<info>, C<warn>,
C<error>, and C<fatal>, in descending priority. This means that, if your
configured logging level is C<warn>, then messages sent with C<debug>
and C<info> methods will be supressed, while C<warn>, C<error> and
C<fatal> messages will make their way through, since their priority is
higher or equal than the configured setting.


=head2 Level Cheking Methods

For every log level, there is a corresponding level checking method,
useful when the logging level may not be reached and we want to block
unnecessary expensive parameter construction, like in:

	if ($log->is_error()) {
		$log->error("The array had: @super_long_array");
	}

If we had just written:

	$log->error("The array had: @super_long_array");

then Perl would have interpolated @super_long_array into the string via
an expensive operation only to figure out shortly after that the string
can be ignored entirely because the configured logging level is lower
than C<'error'>.

The availables level checking methods are:

	$log->is_debug()    # True if debug messages would go through
	$log->is_info()     # True if info  messages would go through
	$log->is_warn()     # True if warn  messages would go through
	$log->is_error()    # True if error messages would go through
	$log->is_fatal()    # True if fatal messages would go through

The C<< $log->is_warn() >> method, for example, returns true if the
logger's current level is C<warn>, C<error> or C<fatal>.



=head1 OTHER METHODS

Developers usually don't have to worry about these methods, except if
dealing with L<Padre::Wx::Main>, L<Padre::Plugin::Devel> or some other
related code.


=head2 new

Returns a new Padre::Log object. You can specify the following
parameters:
  
	my $log = Padre::Log->new(
		filename => '/var/log/padre.log',
		level    => 'info',
		trace    => 1,
	);

=over 4

=item filename

If you want to save Padre's log messages to a log file, you can specify
a target filename for it. Doing this, the new() method will
automatically call C<< set_filename() >> for you.


=item level

This attribute specifies the minimum log level to use. Doing this, the
new() method will automatically call C<< set_log_level() >> for you.


=item trace

This attribute specifies whether a trace output should be issued after
every log message. Doing this, the new() method will automatically call
C<< enable_trace() >> for you.


=back


=head2 set_log_level

	$log->set_log_level('debug');
  
Dynamically switches the minimum log level of your logging object. The
name is specified as a case insensitive string. If you specify anything
other than a valid log level (see "Log Levels" above), or don't pass
anything at all, the default minimum log level will be set to 'C<warn>'.


=head3 Disabling the logger

There is a special log level called 'off' which is higher than any other
level and is never used for logging. So, if you do:

	$log->set_log_level('off');

You will supress all logging.


=head2 set_filename

	$log->set_filename('/var/log/padre.log');

Makes the logging object record its received messages into the specified
file. If it exists, the output will be appended. If it doesn't exist,
the logger will automatically create it. If it can't create it, an error
will be issued to STDERR everytime the logger tries to log something. If
you set the filename value to an empty string, C<undef> or C<0>, STDERR
will be used.


=head2 enable_trace, disable_trace

  $log->enable_trace();   # trace output is on
  $log->disable_trace();  # trace output is off

Enables and disables tracing. The trace output is done with C<<
Carp::longmess >>.



=head1 SEE ALSO

L<Padre::Manual::Hacking>, L<Padre>, L<Padre::Plugin::Devel>, L<Carp>.

This modules's functionallity was heavily based on L<Log::Dispatch> and
L<Log::Log4perl>.



=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut


# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

