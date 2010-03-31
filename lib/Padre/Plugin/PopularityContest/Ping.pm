package Padre::Plugin::PopularityContest::Ping;

# First-generation live call to the Popularity Contest server

use 5.008;
use strict;
use warnings;
use URI              ();
use HTTP::Request    ();
use Padre::Task::LWP ();

our $VERSION = '0.58';
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
		require Padre::Util::SVN;
		my $revision = Padre::Util::SVN::directory_revision($dir);
		$data{svn} = $revision if -d "$dir.svn";
	}

	# Generate the request URL
	my $url = URI->new('http://perlide.org/popularity/v1/ping.html');
	$url->query_form( \%data, ';' );

	# Hand off to the parent constructor
	return $class->SUPER::new( request => HTTP::Request->new( GET => $url->as_string ) );
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
