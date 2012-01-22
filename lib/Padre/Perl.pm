package Padre::Perl;

# TO DO: Merge this into Probe::Perl some day in the future when this is
#       perfected, stable and beyond reproach.

=pod

=head1 NAME

Padre::Perl - A more nuanced "Where is Perl" module than Probe::Perl

=head1 DESCRIPTION

Even though it has only had a single release, L<Probe::Perl> is the "best
practice" method for finding the current Perl interpreter, so that we can
make a system call to a new instance of the same Perl environment.

However, during the development of L<Padre> we have found the feature set
of L<Probe::Perl> to be insufficient.

C<Padre::Perl> is an experimental attempt to improve on L<Probe::Perl>
and support a wider range of situations. The implementation is being
contained to the L<Padre> project until we have competently "solved" all
of the problems that we care about.

=head2 GUI vs Command Line

On some operating systems, different Perl binaries need to be called based
on whether the process will be executing in a graphical environment versus
a command line environment.

On Microsoft Windows F<perl.exe> is the command line Perl binary and
F<wperl.exe> is the windowing Perl binary.

On Mac OS X (Darwin) F<perl.exe> is the command line Perl binary and
F<wxPerl.exe> is a wxWidgets-specific Perl binary.

=head2 PAR Support

PAR executables do not typically support re-invocation, and implementations
that do are only a recent invention, and do not support the normal Perl
flags.

Once implemented, we may try to implement support for them here as well.

=head1 FUNCTIONS

=cut

use 5.008005;
use strict;
use warnings;

# Because this is sometimes used outside the Padre codebase,
# don't put any dependencies on other Padre modules in here.

our $VERSION = '0.94';

my $perl = undef;

=pod

=head2 C<perl>

The C<perl> function is equivalent to (and passes through to) the
C<find_perl_interpreter> method of L<Probe::Perl>.

It should be used when you simply need the "current" Perl executable and
don't have any special needs. The other functions should only be used once
you understand your needs in more detail.

Returns the location of current F<perl> executable, or C<undef> if it
cannot be found.

=cut

sub perl {

	# Find the exact Perl used to launch Padre
	return $perl if defined $perl;

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

=pod

=head2 C<cperl>

The C<cperl> function is a Perl executable location function that
specifically tries to find a command line Perl. In some situations you
may critically need a command line Perl so that proper C<STDIN>, C<STDOUT>
and C<STDERR> handles are available.

Returns a path to a command line Perl, or C<undef> if one cannot be found.

=cut

sub cperl {
	my $path = perl();

	# Cascade failure
	unless ( defined $path ) {
		return;
	}

	if ( $^O eq 'MSWin32' ) {
		if ( $path =~ s/\b(wperl\.exe)\z// ) {

			# Convert to non-GUI
			if ( -f "${path}perl.exe" ) {
				return "${path}perl.exe";
			} else {
				return "${path}wperl.exe";
			}
		}

		# Unknown, give up
		return $path;
	}

	if ( $^O eq 'darwin' ) {
		if ( $path =~ s/\b(wxPerl)\z// ) {

			# Convert to non-GUI
			if ( -f "${path}perl" ) {
				return "${path}perl";
			} else {
				return "${path}wxPerl";
			}
		}

		# Unknown, give up
		return $path;
	}

	# No distinction on this platform, or we have no idea
	return $path;
}

=pod

=head2 C<wxperl>

The C<wxperl> function is a Perl executable location function that
specifically tries to find a windowing Perl for running wxWidgets
applications. In some situations you may critically need a wxWidgets
Perl so that a command line box is not show (Windows) or so that Wx
starts up properly at all (Mac OS X).

Returns a path to a Perl suitable for the execution of L<Wx>-based
applications, or C<undef> if one cannot be found.

=cut

sub wxperl {
	my $path = perl();

	# Cascade failure
	unless ( defined $path ) {
		return;
	}

	if ( $^O eq 'MSWin32' ) {
		if ( $path =~ s/\b(perl\.exe)\z// ) {

			# Convert to GUI version if we can
			if ( -f "${path}wperl.exe" ) {
				return "${path}wperl.exe";
			} else {
				return "${path}perl.exe";
			}
		}

		# Unknown, give up
		return $path;
	}

	if ( $^O eq 'darwin' ) {
		if ( $path =~ s/\b(perl)\z// ) {

			# Convert to Wx launcher
			if ( -f "${path}wxPerl" ) {
				return "${path}wxPerl";
			} else {
				return "${path}perl";
			}
		}

		# Unknown, give up
		return $path;
	}

	# No distinction on this platform, or we have no idea
	return $path;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
