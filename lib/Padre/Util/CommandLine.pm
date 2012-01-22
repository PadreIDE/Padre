package Padre::Util::CommandLine;

# Class to handle command line events
# Currently Part of Padre but it shoule be able to stand on its own
# and maybe moved to a separate package

use 5.008;
use strict;
use warnings;
use utf8;

our $VERSION = '0.94';

my $current_dir;
my @current_list;
my $current_index;
my $last_suggest;

sub tab {
	my ($text) = @_;
	if ( $text =~ m/^:e\s*$/ ) {
		require Cwd;
		my $cwd = Cwd::cwd();
		opendir my $dh, $cwd or die "Could not open $cwd $!";
		@current_list = map { -d "$cwd/$_" ? "$_/" : $_ } grep { $_ ne '.' and $_ ne '..' } sort readdir $dh;
		if ( not @current_list ) {

			# TODO how to handle empty dir?
		}
		$current_index = 0;
		$last_suggest  = ":e $current_list[$current_index]";
		return $last_suggest;

	} elsif ( defined $last_suggest and $text eq $last_suggest ) {
		$current_index++;
		$last_suggest = ":e $current_list[$current_index]";
		return $last_suggest;
	}
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
