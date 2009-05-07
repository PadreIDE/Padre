package Padre::SingleInstance;

# Single Instance Client

use 5.008;
use strict;
use warnings;
use Carp;
use IO::File;
use IO::Socket;

# constants
use constant REMOTE_HOST => '127.0.0.1';
use constant SERVER_PORT => 9999;

our $VERSION = '0.34';

#
# checks whether another instance is running or not
#
sub is_running {
	my $self = shift;

	my $socket = IO::Socket::INET->new(
		PeerAddr => REMOTE_HOST,
		PeerPort => SERVER_PORT,
		Proto    => "tcp",
		Type     => SOCK_STREAM
	);

	if ($socket) {
		print "It is alive\n";
		if ( $#ARGV >= 0 ) {
			foreach my $argnum ( 0 .. $#ARGV ) {
				my $arg = $ARGV[$argnum];
				print $socket "open $ARGV[$argnum]\n";
			}
			close $socket
				or croak "Cant close socket\n";
		} else {
			print $socket "restore_focus";
		}
		die "Sent it my work.... bye bye\n";
	}

	return $socket ? 1 : 0;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
