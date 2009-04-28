package Padre::Wx::Net;

### This is a half-assed first attempt. Don't use this.

=pod

=head1 NAME

Padre::Wx::Net - Padre Internal IPC Library

=head1 DESCRIPTION

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.34';

#####################################################################
# Server Functionality

sub localhost_server {
	my $class      = shift;
	my $parent     = shift;
	my $port       = shift;
	my $on_connect = shift;
	my $address    = Wx::IPV4address->new;
	$address->SetAnyAddress;
	$address->SetService(4444);
	my $sock = Wx::DatagramSocket->new($address);

}

sub localhost_server_connect {
	my $sock   = shift;
	my $this   = shift;
	my $event  = shift;
	my $addr   = Wx::IPV4address->new;
	my $buffer = '';
	$sock->RecvFrom( $addr, $buffer, 1000 );

}

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
