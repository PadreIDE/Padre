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
use Params::Util qw{_INSTANCE};
use HTTP::Request  ();
use HTTP::Response ();
use Padre::Task    ();

our $VERSION = '0.43';
our @ISA     = 'Padre::Task';

use Class::XSAccessor getters => {
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
	my $self = shift->SUPER::new(
		@_,
		response => undef,
	);

	unless ( _INSTANCE( $self->request, 'HTTP::Request' ) ) {
		Carp::croak("Missing or invalid 'request' for Padre::Task::LWP");
	}

	return $self;
}

=head2 request

The C<request> method returns the L<HTTP::Request> object that was provided
to the constructor.

=head2 response

Before the C<run> method has been fired the C<response> method returns
C<undef>.

After the C<run> method has been fired the C<response> method returns the
L<HTTP::Response> object for the L<LWP::UserAgent> request.

Typically, you would use this in the C<finish> method for the task,
if you wish to take any further actions in L<Padre> based on the result
of the HTTP call.

=cut

######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Execute the web request
	require LWP::UserAgent;
	$self->{response} = LWP::UserAgent->new(
		agent => "Padre/$VERSION",
	)->request( $self->request );

	# Remove the CODE references from the response.
	# They aren't needed any more, and they won't survive
	# the serialization back to the main thread.
	delete $self->{response}->{handlers};

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
