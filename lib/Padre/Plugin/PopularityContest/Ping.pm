package Padre::Plugin::PopularityContest::Ping;

# First-generation live call to the Popularity Contest server

use strict;
use warnings;
use URI              ();
use HTTP::Request    ();
use Padre::Task::LWP ();

our $VERSION = '0.41';
our @ISA     = 'Padre::Task::LWP';

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
	my $url = URI->new('http://perlide.org/popularity/v1/ping');
	$url->query_form( \%data, ';' );

	# Hand off to the parent constructor
	return $class->SUPER::new( request => HTTP::Request->new( GET => $url->as_string ) );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
