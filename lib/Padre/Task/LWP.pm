package Padre::Task::LWP;

=pod

=head1 NAME

Padre::Task::LWP - Generic http client background processing task

=head1 SYNOPSIS

  # Fire and forget HTTP request
  Padre::Task::LWP->new(
      request => HTTP::Request->new(
          GET => 'http://perlide.org',
      ),
  )->schedule;

=head1 DESCRIPTION

Sending and receiving data via HTTP.

=head1 METHODS

=cut

use strict;
use warnings;
use Params::Util   qw{_INSTANCE};
use HTTP::Request  ();
use HTTP::Response ();
use Padre::Task    ();

our $VERSION = '0.35';
our @ISA     = 'Padre::Task';

use Class::XSAccessors
	getters => {
		request  => 'request',
		response => 'response',
	};





######################################################################
# Constructor

=pod

=head2 new

  my $task = Padre::Task::LWP->new(
      request => HTTP::Request->new(
          GET => 'http://perlide.org',
      ),
  );

The C<new> constructor creates a L<Padre::Task> for a background HTTP request.

It takes a single addition parameter C<request> which is a fully-prepared
L<HTTP::Request> object for the request.

Returns a new L<Padre::Task::LWP> object, or throws an exception on error.

=cut

sub new {
	my $self = shift->SUPER::new( @_,
		response => undef,
	);

	unless ( _INSTANCE($self->request, 'HTTP::Request') ) {
		Carp::croak("Missing or invalid 'request' for Padre::Task::LWP");
	}

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Execute the web request
	require LWP::UserAgent;
	$self->{response} = LWP::UserAgent->new(
		agent => "Padre/$VERSION",
	)->request($self->request);

	return 1;
}

1;

__END__

=pod

=head1 SEE ALSO

This class inherits from C<Padre::Task> and its instances can be scheduled
using C<Padre::TaskManager>.

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
