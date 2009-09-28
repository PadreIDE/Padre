package Padre::Task::HTTPClient;

use 5.008;
use strict;
use warnings;

# Use all modules which may provide services for us:

our $VERSION = '0.47';

=pod

=head1 NAME

Padre::Task::HTTPClient - HTTP client for Padre

=head1 DESCRIPTION

Padre::Task::HTTPClient provies a common API for HTTP access to Padre.

As we don't want a specific HTTP client module dependency to a
network-independent application like Padre, this module searches
for installed HTTP client modules and uses one of them.

=head1 METHODS

=head2 new

  my $http = Padre::Task::HTTPClient->new();

The C<new> constructor lets you create a new B<Padre::Task::HTTPClient> object.

Returns a new B<Padre::Task::HTTPClient> or dies on error.

=cut

sub new {

	my $class = shift;

	my %args   = @_;

	return if ( !defined($args{URL}) ) or ( $args{URL} eq '' );

	# Prepare information
	$args{headers}->{'X-Padre'} ||= 'Padre version '.$VERSION.' '.Padre::Util::revision();
	$args{method} ||= 'GET';

	my $self;

	# Each module will be tested and the first working one should return
	# a object, all others should return nothing (undef)
	for ( 'LWP' ) {
		require 'Padre/Task/HTTPClient/'.$_.'.pm';
		$self = "Padre::Task::HTTPClient::$_"->new(%args);
		next unless defined($self);
		return $self;
	}

		return;

}

#=head2 atime
#
#  $file->atime;
#
#Returns the last-access time of the file.
#
#This is usually not possible for non-local files, in these cases, undef
#is returned.
#
#=cut
#
## Fallback if the module has no such function:
#sub atime {
#	return;
#}
#
1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
