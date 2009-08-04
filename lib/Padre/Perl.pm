package Padre::Perl;

# An enhanced replacement for Probe::Perl that is able to understand the
# difference between a Perl for GUI purposes and a Perl for command line
# purposes.

# TODO: Merge this into Probe::Perl some day in the future when this is
#       perfected, stable and beyond reproach.

use 5.008005;
use strict;
use warnings;

# Because this is sometimes used outside the Padre codebase,
# don't put any dependencies on other Padre modules in here.

my $perl = undef;

sub perl () {
	# Find the exact Perl used to launch Padre
	return $perl if defined $perl;
	require Probe::Perl;
	require File::Which;

	# Use the most correct method first
	require Probe::Perl;
	my $_perl = Probe::Perl->find_perl_interpreter;
	if ( defined $_perl ) {
		$perl = $_perl;
		return $perl;
	}

	# Fallback to a simpler way
	require File::Which;
	$_perl = scalar File::Which::which('perl');
	$perl  = $_perl;
	return $perl;
}

sub wperl () {
	my $perl = perl();
	unless ( $^O eq 'MSWin32' ) {
		# No distinction on this platform
		return $perl;
	}

	if ( $perl =~ s/\b(perl\.exe)\z// ) {
		# Convert to GUI
		return "${perl}wperl.exe";
	}

	# Unknown, give up
	return $perl;
}

sub cperl () {
	my $perl = perl();
	unless ( $^O eq 'MSWin32' ) {
		# No distinction on this platform
		return $perl;
	}

	if ( $perl =~ s/\b(wperl\.exe\z)// ) {
		# Convert to non-gui
		return "${perl}perl.exe";
	}

	# Unknown, give up
	return $perl;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
