package Padre::Util;

=pod

=head1 NAME

Padre::Util - Padre Non-Wx Utility Functions

=head1 DESCRIPTION

The Padre::Util package is a internal storage area for miscellaneous
functions that aren't really Padre-specific that we want to throw
somewhere convenient so they won't clog up task-specific packages.

All functions are exportable and documented for maintenance purposes,
but except for in the L<Padre> core distribution you are discouraged in the
strongest possible terms from using these functions, as they may be
moved, removed or changed at any time without notice.

=head1 FUNCTIONS

=cut

use 5.008;
use strict;
use warnings;
use Exporter   ();
use FindBin    ();
use File::Spec ();
use List::Util qw(first);
use File::Basename ();
use Carp           ();
use POSIX          ();

our $VERSION   = '0.41';
our @ISA       = 'Exporter';
our @EXPORT_OK = qw(newline_type get_matches _T);

#####################################################################
# Officially Supported Constants

# Convenience constants for the operating system
use constant WIN32 => !!( $^O eq 'MSWin32' );
use constant MAC   => !!( $^O eq 'darwin' );
use constant UNIX => !( WIN32 or MAC );

# Padre targets the three largest Wx backends
# 1. Win32 Native
# 2. Mac OS X Native
# 3. Unix GTK
# The following defined reusable constants for these platforms,
# suitable for use in Wx platform-specific adaptation code.
# Currently (and a bit naively) we align these to the platforms.
use constant WXWIN32 => WIN32;
use constant WXMAC   => MAC;
use constant WXGTK   => UNIX;

# The local newline type
use constant NEWLINE => WIN32 ? 'WIN' : MAC ? 'MAC' : 'UNIX';

#####################################################################
# Miscellaneous Functions

=pod

=head2 newline_type

    my $type = newline_type( $string );

Returns None if there was not CR or LF in the file.

Returns UNIX, Mac or Windows if only the appropriate newlines
were found.

Returns Mixed if line endings are mixed.

=cut

sub newline_type {
	my $text = shift;

	my $CR   = "\015";
	my $LF   = "\012";
	my $CRLF = "\015\012";

	return "None" if not defined $text;
	return "None" if $text !~ /$LF/ and $text !~ /$CR/;
	return "UNIX" if $text !~ /$CR/;
	return "MAC"  if $text !~ /$LF/;

	$text =~ s/$CRLF//g;
	return "WIN" if $text !~ /$LF/ and $text !~ /$CR/;

	return "Mixed";
}

=pod

=head2 get_matches

Parameters:

* The text in which we need to search

* The regular expression

* The offset within the text where we the last match started so the next
  forward match must start after this.

* The offset within the text where we the last match ended so the next
  backward match must end before this.

* backward bit (1 = search backward, 0 = search forward) - Optional. Defaults to 0.

=cut

sub get_matches {
	my ( $text, $regex, $from, $to, $backward ) = @_;
	die "missing parameters" if @_ < 4;

	use Encode;
	$text = Encode::encode( 'utf-8', $text );

	my @matches;
	while ( $text =~ /$regex/g ) {
		my $e = pos($text);
		my $s = $e - length($&);
		push @matches, [ $s, $e ];
	}

	my $pair;
	if ($backward) {
		$pair = first { $to > $_->[1] } reverse @matches;
		if ( not $pair and @matches ) {
			$pair = $matches[-1];
		}
	} else {
		$pair = first { $from < $_->[0] } @matches;
		if ( not $pair and @matches ) {
			$pair = $matches[0];
		}
	}

	my ( $start, $end );
	( $start, $end ) = @$pair if $pair;

	return ( $start, $end, @matches );
}

=pod

=head2 _T

The _T function is used for strings that you do not want to translate
immediately, but you will be translating later (multiple times).

The only reason this function needs to exist at all is so that the
translation tools can identify the string it refers to as something that
needs to be translated.

Functionally, this function is just a direct pass-through with no effect.

=cut

sub _T {
	shift;
}

=pod

=head2 pwhich

  # Find the prove utility
  my $prove = Padre::Util::pwhich('prove');

The C<pwhich> function discovers the path to the installed perl script
which is in the same installation directory as the Perl user to run
Padre itself, ignoring the regular search PATH.

Returns the locally-formatted path to the script, or false (null string)
if the utilily does not exist in the current Perl installation.

=cut

sub pwhich {
	my $bin = 1;
}

#####################################################################
# Developer-Only Functions

# This is pretty hacky
sub svn_directory_revision {
	my $dir = shift;

	# Find the entries file
	my $entries = File::Spec->catfile( $dir, '.svn', 'entries' );
	return unless -f $entries;

	# Find the headline revision
	local $/ = undef;
	open( my $fh, "<", $entries ) or return;
	my $buffer = <$fh>;
	close($fh);

	# Find the first number after the first occurance of "dir".
	unless ( $buffer =~ /\bdir\b\s+(\d+)/m ) {
		return undef;
	}

	# Quote this to prevent certain aliasing bugs
	return "$1";
}

#####################################################################
# Shared Resources

sub share {
	return File::Spec->catdir( $FindBin::Bin, File::Spec->updir, 'share' ) if $ENV{PADRE_DEV};
	if ( defined $ENV{PADRE_PAR_PATH} ) {

		# File::ShareDir new style path
		my $path = File::Spec->catdir( $ENV{PADRE_PAR_PATH}, 'inc', 'auto', 'share', 'dist', 'Padre' );
		return $path if -d $path;

		# File::ShareDir old style path
		$path = File::Spec->catdir( $ENV{PADRE_PAR_PATH}, 'inc', 'share' );
		return $path if -d $path;
	}

	# rely on automatic handling of everything
	require File::ShareDir::PAR;
	return File::ShareDir::PAR::dist_dir('Padre');
}

sub sharedir {
	File::Spec->catdir( share(), @_ );
}

sub sharefile {
	File::Spec->catfile( share(), @_ );
}

sub find_perldiag_translations {
	my %languages;
	foreach my $path (@INC) {
		my $dir = File::Spec->catdir( $path, 'POD2' );
		next if not -e $dir;
		if ( opendir my $dh, $dir ) {
			while ( my $lang = readdir $dh ) {
				next if $lang eq '.' or $lang eq '..';
				if ( -e File::Spec->catfile( $dir, $lang, 'perldiag.pod' ) ) {
					$languages{$lang} = 1;
				}
			}
		}
	}
	return sort keys %languages;
}

=pod get_project_rcs

Given a project dir (see "get_project_dir"), returns the project's 
Revision Control System (RCS) by name. This can be either 'CVS', 
'SVN' or 'GIT'. Returns undef if none was found.

=cut

sub get_project_rcs {
	my $project_dir = shift;

	my %evidence_of = (
		'CVS' => 'CVS',
		'SVN' => '.svn',
		'GIT' => '.git',
	);

	foreach my $rcs ( keys %evidence_of ) {
		my $dir = File::Spec->catdir( $project_dir, $evidence_of{$rcs} );
		return $rcs if -d $dir;
	}
	return;
}

=pod

=head2 get_project_dir

Given a file it will try to locate the root directory of the given
project. This is a temporary work around till we get full project
support but it is used by some (SVK) plugins.

=cut

sub get_project_dir {
	my $filename = shift;
	return unless $filename;

	# check for potential relative path on filename
	if ( $filename =~ m{\.\.} ) {
		require Cwd;
		$filename = Cwd::realpath($filename);
	}
	my $olddir = File::Basename::dirname($filename);
	my $dir    = $olddir;
	while (1) {
		return $dir if -e File::Spec->catfile( $dir, 'Makefile.PL' );
		return $dir if -e File::Spec->catfile( $dir, 'Build.PL' );
		$olddir = $dir;
		$dir    = File::Basename::dirname($dir);

		last if $olddir eq $dir;
	}
	return;
}

SCOPE: {
	my $logging;
	my $trace;

	sub set_logging {
		$logging = shift;
	}

	sub set_trace {
		$trace = shift;
	}

	sub debug {
		return if not $logging;

		my $ts = POSIX::strftime( "%H:%M:%S", localtime() );
		print STDERR "$ts - @_\n";
		if ($trace) {
			print STDERR Carp::longmess();
		} else {
			my ( $package, $filename, $line ) = caller;
			print STDERR "           in line $line of $filename\n";
		}
	}
}

1;

__END__

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
