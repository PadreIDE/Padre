package Padre::Logger;

=pod

=head1 NAME

Padre::Logger - Compile-time logging library for Padre

=head1 SYNOPSIS

  # In the launch/dev.pl script
  BEGIN {
      $Padre::Logger::DEBUG = 1;
  }
  
  use Padre;
  
  # In each Padre::Foo class
  use Padre::Logger;
  
  sub method {
      TRACE('->method') if DEBUG;
      
      # Your code as normal
  }

=head1 DESCRIPTION

This is a logging utility class for Padre. It provides a basic set of
simple functionality that allows for loggin/debugging/tracing statements to be
used in Padre that will compile out of the application when not in use.

=cut

use 5.008;
use strict;
use warnings;
use Padre::Constant ();

our $VERSION = '0.55';

sub import {
	my $pkg = ( caller() )[0];
	eval <<"END_PERL";
package $pkg;
use constant DEBUG => !! (
	defined(\$${pkg}::DEBUG)     ? \$${pkg}::DEBUG :
	defined(\$Padre::Logger::DEBUG) ? \$Padre::Logger::DEBUG :
	\$ENV{PADRE_DEBUG}
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
	my $time    = scalar localtime time;
	my $package = ( caller() )[0];
	my $logfile = Padre::Constant::LOG_FILE;
	open my $fh, '>>', $logfile or return;
	foreach my $message (@_) {
		print $fh sprintf(
			"%s %s%s\n",
			$time,
			$package,
			$message,
		);
	}
	close $fh;
	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
