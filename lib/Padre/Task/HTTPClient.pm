package Padre::Task::HTTPClient;

use 5.008;
use strict;
use warnings;
use Params::Util qw{_CODE _INSTANCE};
use URI              ();
use HTTP::Request    ();
use Padre::Task::LWP ();

our $VERSION = '0.47';
our @ISA     = 'Padre::Task::LWP';

=pod

=head1 NAME

Padre::Task::HTTPClient - Generic http client background processing task

=head1 SYNOPSIS

=head1 DESCRIPTION

Sending and receiving data via HTTP.

=cut

# TODO this should probably run later,
# not when the plugin is enabled
sub new {
	my $class = shift;

	# Prepare the information to send
	my %data = (
		padre  => $VERSION,
		perl   => $],
		osname => $^O,
	);
	if ( $0 =~ /padre$/ ) {
		my $dir = $0;
		$dir =~ s/padre$//;
		my $revision = Padre::Util::svn_directory_revision($dir);
		if ( -d "$dir.svn" ) {
			$data{svn} = $revision;
		}
	}

	# Generate the request URL
	my $url = URI->new('http://peride.org/popularity');
	$url->query_form( \%data, ';' );

	# Hand off to the parent constructor
	return $class->SUPER::new( request => HTTP::Request->new( GET => $url->as_string ) );
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
