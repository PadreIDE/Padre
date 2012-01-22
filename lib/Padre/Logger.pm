package Padre::Logger;

=pod

=head1 NAME

Padre::Logger - Compile-time logging library for Padre

=head1 SYNOPSIS

  # In the launcher script
  $ENV{PADRE_DEBUG} = 1;



  use Padre;

  # In each Padre::Foo class
  use Padre::Logger;

  sub method {
      TRACE('->method') if DEBUG;

      # Your code as normal
  }

=head1 DESCRIPTION

This is a logging utility class for Padre. It provides a basic set of
simple functionality that allows for logging/debugging/tracing statements to be
used in Padre that will compile out of the application when not in use.

=cut

use 5.008;
use strict;
use warnings;
use threads;
use threads::shared;
use Carp            ();
use Time::HiRes     ();
use Padre::Constant ();

our $VERSION = '0.94';

# Handle the PADRE_DEBUG environment variable
BEGIN {
	if ( $ENV{PADRE_DEBUG} ) {
		if ( $ENV{PADRE_DEBUG} eq '1' ) {

			# Debug everything
			$Padre::Logger::DEBUG = 1;
		} else {

			# Debug a single class
			eval "\$$ENV{PADRE_DEBUG}::DEBUG = 1;";
		}
	}
}

sub import {
	if ( $_[1] and $_[1] eq ':ALL' ) {
		$Padre::Logger::DEBUG = 1;
	}
	my $pkg = ( caller() )[0];
	eval <<"END_PERL";
package $pkg;

use constant DEBUG => !! (
	defined(\$${pkg}::DEBUG) ? \$${pkg}::DEBUG : \$Padre::Logger::DEBUG
);

BEGIN {
	*TRACE = *Padre::Logger::TRACE;
	TRACE('::DEBUG enabled') if DEBUG;
}

1;
END_PERL
	die("Failed to enable debugging for $pkg") if $@;
	return;
}

# Global trace function
sub TRACE {
	my $time    = Time::HiRes::time;
	my $caller  = ( caller(1) )[3] || 'main';
	my $logfile = Padre::Constant::LOG_FILE;
	my $thread =
		  ( $INC{'threads.pm'} and threads->self->tid )
		? ( '(Thread ' . threads->self->tid . ') ' )
		: '';

	# open my $fh, '>>', $logfile or return;
	foreach (@_) {

		# print $fh sprintf(
		print sprintf(
			"# %.5f %s%s %s\n",
			$time,
			$thread,
			$caller,
			string($_),
		);
	}
	if ( $ENV{PADRE_DEBUG_STACK} ) {
		print Carp::longmess(), "\n";
		print '-' x 50, "\n";
	}

	# close $fh;
	return;
}

sub string {
	require Devel::Dumpvar;
	my $object = shift;
	my $shared = ( $INC{'threads/shared.pm'} and threads::shared::is_shared($object) ) ? ' : shared' : '';
	my $string =
		ref($object)
		? Devel::Dumpvar->_refstring($object)
		: Devel::Dumpvar->_scalar($object);
	return $string . $shared;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
