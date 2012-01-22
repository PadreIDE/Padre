package Padre::Plugin::PopularityContest::Ping;

# First-generation live call to the Popularity Contest server

use 5.008;
use strict;
use warnings;
use URI              ();
use Padre::Task::LWP ();

our $VERSION = '0.94';
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

	# Hand off to the parent constructor
	return $class->SUPER::new(
		url   => 'http://perlide.org/popularity/v1/ping.html',
		query => \%data,
	);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
