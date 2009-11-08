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
use Carp           ();
use Exporter       ();
use FindBin        ();
use Cwd            ();
use File::Spec     ();
use File::Basename ();
use List::Util     ();
use POSIX          ();
use Padre::Constant();

our $VERSION   = '0.50';
our @ISA       = 'Exporter';
our @EXPORT_OK = qw{ newline_type get_matches _T };





#####################################################################
# Officially Supported Constants

# Convenience constants for the operating system
# NOTE: They're now in Padre::Constant, if you miss them, please use them from there
#use constant WIN32 => !!( $^O eq 'MSWin32' );
#use constant MAC   => !!( $^O eq 'darwin' );
#use constant UNIX => !( WIN32 or MAC );

# Padre targets the three largest Wx backends
# 1. Win32 Native
# 2. Mac OS X Native
# 3. Unix GTK
# The following defined reusable constants for these platforms,
# suitable for use in Wx platform-specific adaptation code.
# Currently (and a bit naively) we align these to the platforms.
# NOTE: They're now in Padre::Constant, if you miss them, please use them from there
#use constant WXWIN32 => WIN32;
#use constant WXMAC   => MAC;
#use constant WXGTK   => UNIX;

# The local newline type
# NOTE: It's now in Padre::Constant, if you miss them, please use it from there
#use constant NEWLINE => Padre::Constant::WIN32 ? 'WIN' : Padre::Constant::MAC ? 'MAC' : 'UNIX';





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
	while ( $text =~ /$regex/mg ) {
		my $e = pos($text);
		my $s = $e - length($1);
		push @matches, [ $s, $e ];
	}

	my $pair;
	if ($backward) {
		$pair = List::Util::first { $to > $_->[1] } reverse @matches;
		if ( not $pair and @matches ) {
			$pair = $matches[-1];
		}
	} else {
		$pair = List::Util::first { $from < $_->[0] } @matches;
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

# Pasting more background information for people that don't understand
# the POD docs, because at least one person has accidentally broken this
# by changing it (not cxreg, he actually asked first) :)
#15:31 cxreg Alias: er, how it's just "shift" ?
#15:31 Alias cxreg: Wx has a gettext implementation
#15:31 Alias Wx::gettext
#15:31 Alias That's the "translate right now" function
#15:31 Alias But we need a late-binding version, for things that need to be translated, but are kept in memory (for various reasons) as English and only get translated at the last second
#15:32 Alias So in that case, we do a Wx::gettext($string)
#15:32 Alias The problem is that the translation tools can't tell what $string is
#15:32 Alias The translation tools DO, however, recognise _T as a translatable string
#15:33 Alias So we use _T as a silent pass-through specifically to indicate to the translation tools that this string needs translating
#15:34 Alias If we did everything as an up-front translation we'd need to flush a crapton of stuff and re-initialise it every time someone changed languages
#15:35 Alias Instead, we flush the hidden dialogs and rebuild the entire menu
#15:35 Alias But most of the rest we do with the delayed _T strings
#15:37 cxreg i get the concept, it's just so magical
#15:38 Alias It works brilliantly :)
#15:38 cxreg do you replace the _T symbol at runtime?
#15:39 Alias symbol?
#15:39 Alias Why would we do that?
#15:40 cxreg in order to actually instrument the translation, i wasn't sure if you were swapping out the sub behind the _T symbol
#15:40 Alias oh, no
#15:40 Alias _T is ONLY there to hint to the translation tools
#15:40 Alias The PO editors etc
#15:40 Alias my $english = _T('Hello World!'); $gui->set_title( Wx::gettext($english) );
#15:41 Alias It does absolutely nothing inside the code itself
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
		return;
	}

	# Quote this to prevent certain aliasing bugs
	return "$1";
}





#####################################################################
# Shared Resources

sub share {
	if ( $ENV{PADRE_DEV} ) {
		return File::Spec->catdir(
			$FindBin::Bin,
			File::Spec->updir, 'share'
		);
	}

	#    if ( defined $ENV{PADRE_PAR_PATH} ) {
	#        # File::ShareDir new style path
	#        my $path = File::Spec->catdir(
	#            $ENV{PADRE_PAR_PATH},
	#            'inc', 'auto', 'share', 'dist', 'Padre'
	#        );
	#        return $path if -d $path;
	#
	#        # File::ShareDir old style path
	#        $path = File::Spec->catdir(
	#            $ENV{PADRE_PAR_PATH},
	#            'inc', 'share'
	#        );
	#        return $path if -d $path;
	#    }

	# rely on automatic handling of everything
	require File::ShareDir;
	return File::ShareDir::dist_dir('Padre');
}

sub sharedir {
	File::Spec->catdir( share(), @_ );
}

sub sharefile {
	File::Spec->catfile( share(), @_ );
}

sub splash {
	my $original = Padre::Util::sharefile('padre-splash-ccnc.bmp');
	return -f $original ? $original : Padre::Util::sharefile('padre-splash.bmp');
}

sub find_perldiag_translations {
	my %languages;
	foreach my $path (@INC) {
		my $dir = File::Spec->catdir( $path, 'POD2' );
		next if not -e $dir;
		if ( opendir my $dh, $dir ) {
			while ( my $lang = readdir $dh ) {
				next if $lang eq '.';
				next if $lang eq '..';
				if ( -e File::Spec->catfile( $dir, $lang, 'perldiag.pod' ) ) {
					$languages{$lang} = 1;
				}
			}
		}
	}
	return sort keys %languages;
}

=pod

=head2 get_project_rcs

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
		my $dir = File::Spec->catdir(
			$project_dir,
			$evidence_of{$rcs},
		);
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
	my $filename = shift or return;

	# Check for potential relative path on filename
	if ( $filename =~ m{\.\.} ) {
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





######################################################################
# Cloned Functions

=pod

=head2 parse_version

B<This is a clone of ExtUtils::MakeMaker parse_version to prevent loading
a bunch of other modules>

    my $version = Padre::Util::parse_version($file);

Parse a $file and return what $VERSION is set to by the first assignment.
It will return the string "undef" if it can't figure out what $VERSION
is. $VERSION should be for all to see, so C<our $VERSION> or plain $VERSION
are okay, but C<my $VERSION> is not.

parse_version() will try to C<use version> before checking for
C<$VERSION> so the following will work.

    $VERSION = qv(1.2.3);

=cut

sub parse_version {
	my $parsefile = shift;
	my $result;
	local $/ = "\n";
	local $_;
	open( my $fh, '<', $parsefile ) or die "Could not open '$parsefile': $!";
	my $inpod = 0;
	while (<$fh>) {
		$inpod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $inpod;
		next if $inpod || /^\s*#/;
		chop;
		next if /^\s*(if|unless)/;
		next unless m{(?<!\\) ([\$*]) (([\w\:\']*) \bVERSION)\b .* =}x;
		my $eval = qq{
			package Padre::Util::_version;
			no strict;
			BEGIN { eval {
				# Ensure any version() routine which might have leaked
				# into this package has been deleted.  Interferes with
				# version->import()
				undef *version;
				require version;
				"version"->import;
			} }
			local $1$2;
			\$$2=undef;
			do {
				$_
			};
			\$$2;
		};
		local $^W = 0;
		$result = eval($eval);
		warn "Could not eval '$eval' in $parsefile: $@" if $@;
		last if defined $result;
	}
	close $fh;
	return $result;
}





######################################################################
# Logging and Debugging

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

		my $logfile = Padre::Constant::LOG_FILE;
		open my $fh, '>>', $logfile or return;

		my $ts = POSIX::strftime( "%H:%M:%S", localtime() );

		print $fh "$ts - @_\n";
		if ($trace) {
			print $fh Carp::longmess();
		} else {
			my ( $package, $filename, $line ) = caller;
			print $fh "           in line $line of $filename\n";
		}
	}
}

sub humanbytes {

	my $Bytes = $_[0] || 0;

	eval { require Format::Human::Bytes; };
	return $Bytes if $@; # Doesn't look good, but works

	return Format::Human::Bytes::base2( $Bytes, 1 );

}

# Returns the memory currently used by this application:
sub process_memory {
	if (Padre::Constant::UNIX) {
		open my $meminfo, "/proc/self/stat" or return;
		return ( split( / /, <$meminfo> ) )[22];
	} elsif (Padre::Constant::WIN32) {
		require Padre::Util::Win32;
		return Padre::Util::Win32::GetCurrentProcessMemorySize();
	}
	return;
}

# TODO: A much better variant would be a constant set by svn.
sub revision {
	if ( $0 =~ /padre$/ ) {
		my $dir = $0;
		$dir =~ s/padre$//;
		my $revision = Padre::Util::svn_directory_revision($dir);
		if ( -d "$dir.svn" ) {
			return 'r' . $revision;
		}
	}
	return;
}

1;

__END__

=pod

=head1 COPYRIGHT

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
