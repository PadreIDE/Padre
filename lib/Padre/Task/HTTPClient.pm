package Padre::Task::HTTPClient;

use strict;
use warnings;
use Params::Util qw{_CODE _INSTANCE};
use Padre::Task    ();
use Padre::Current ();
use Padre::Wx      ();

our $VERSION = '0.34';
use base 'Padre::Task';

=pod

=head1 NAME

Padre::Task::HTTPClient - Generic http client background processing task

=head1 SYNOPSIS

=head1 DESCRIPTION

Sending and receiving data via HTTP.

=cut

# TODO this should probably run later,
# not when the plugin is enabled
sub run {
	my $self = shift;

	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	$ua->agent("Padre/$VERSION");
	my $url = $ENV{PADRE_URL} || 'http://peride.org/popularity';
	my $req = HTTP::Request->new( POST => $url );
	$req->content_type('application/x-www-form-urlencoded');

	# TODO the data here has to be controlled by the user
	my %data;
	$data{fname} = 'Foo';
	$data{lname} = 'Bar';

	#	$data{padre} = $VERSION;
	#	$data{perl}  = $];
	#	$data{os}    = $^O;

	require YAML::Tiny;
	my $content = YAML::Tiny::Dump( \%data );
	$req->content($content);

	my $res = $ua->request($req);

	return 1;
}

1;

__END__

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
