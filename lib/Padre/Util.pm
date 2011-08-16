package Padre::Util;

=pod

=head1 NAME

Padre::Util - Padre non-Wx Utility Functions

=head1 DESCRIPTION

The C<Padre::Util> package is a internal storage area for miscellaneous
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
use Carp            ();
use Exporter        ();
use FindBin         ();
use Cwd             ();
use File::Spec      ();
use List::Util      ();
use Padre::Constant (); ### NO other Padre:: dependencies

# If we make $VERSION an 'our' variable the parse_variable() function breaks
use vars qw{ $VERSION $COMPATIBLE };

BEGIN {
	$VERSION    = '0.90';
	$COMPATIBLE = '0.81';
}

our @ISA       = 'Exporter';
our @EXPORT_OK = '_T';
our $DISTRO    = undef;





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

# Pulled back from Padre::Constant as it wasn't a constant in the first place
sub DISTRO {
	return $DISTRO if defined $DISTRO;

	if (Padre::Constant::WIN32) {

		# Inherit from the main Windows classification
		require Win32;
		$DISTRO = uc Win32::GetOSName();

	} elsif (Padre::Constant::MAC) {
		$DISTRO = 'MAC';

	} else {

		# Try to identify a more specific linux distribution
		local $@;
		eval {
			if ( open my $lsb_file, '<', '/etc/lsb-release' )
			{
				while (<$lsb_file>) {
					next unless /^DISTRIB_ID\=(.+?)[\r\n]/;
					if ( $1 eq 'Ubuntu' ) {
						$DISTRO = 'UBUNTU';
					}
					last;
				}
			}
		};
	}

	$DISTRO ||= 'UNKNOWN';

	return $DISTRO;
}





#####################################################################
# Idioms and Miscellaneous Functions

=pod

=head2 C<slurp>

    my $content = Padre::Util::slurp( $file );
    if ( $content ) {
        print $$content;
    } else {
        # Handle errors appropriately
    }

This is a simple slurp implementation, provided as a convenience for
internal Padre use when loading trivial unimportant files for which
we don't need anything more robust.

All file reading is done with C<binmode> enabled, and data is returned by
reference to avoid needless copying.

Returns the content of the file as a SCALAR reference if the file exists
and can be read.

Returns false if loading of the file failed.

This function is only expected to be used in situations where the file
should almost always exist, and thus the reason why reading the file
failed isn't really important.

=cut

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or return '';
	binmode $fh;
	local $/ = undef;
	my $content = <$fh>;
	close $fh;
	return \$content;
}

=pod

=head2 C<newline_type>

    my $type = Padre::Util::newline_type( $string );

Returns C<None> if there was not C<CR> or C<LF> in the file.

Returns C<UNIX>, C<Mac> or C<Windows> if only the appropriate newlines
were found.

Returns C<Mixed> if line endings are mixed.

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

=head2 C<parse_variable>

    my $version = Padre::Util::parse_variable($file, 'VERSION');

Parse a C<$file> and return what C<$VERSION> (or some other variable) is set to
by the first assignment.

It will return the string C<"undef"> if it can't figure out what C<$VERSION>
is. C<$VERSION> should be for all to see, so C<our $VERSION> or plain
C<$VERSION> are okay, but C<my $VERSION> is not.

C<parse_variable()> will try to C<use version> before checking for
C<$VERSION> so the following will work.

    $VERSION = qv(1.2.3);

Originally based on C<parse_version> from L<ExtUtils::MakeMaker>.

=cut

sub parse_variable {
	my $parsefile = shift;
	my $variable = shift || 'VERSION';
	my $result;
	local $/ = "\n";
	local $_;
	open( my $fh, '<', $parsefile ) #-# no critic (RequireBriefOpen)
		or die "Could not open '$parsefile': $!";
	my $inpod = 0;

	while (<$fh>) {
		$inpod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $inpod;
		next if $inpod || /^\s*#/;
		chop;
		next if /^\s*(if|unless)/;
		if ( $variable eq 'VERSION' and m{^ \s* package \s+ \w[\w\:\']* \s+ (v?[0-9._]+) \s* ;  }x ) {
			local $^W = 0;
			$result = $1;
		} elsif (m{(?<!\\) ([\$*]) (([\w\:\']*) \b$variable)\b .* =}x) {
			my $eval = qq{
				package # Hide from PAUSE
					ExtUtils::MakeMaker::_version;
				no strict;
				BEGIN { eval {
					# Ensure any version() routine which might have leaked
					# into this package has been deleted.  Interferes with
					# version->import
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

			# what policy needs to be disabled here????
			$result = eval($eval);

			warn "Could not eval '$eval' in $parsefile: $@" if $@;
		} else {
			next;
		}
		last if defined $result;
	}
	close $fh;

	$result = "undef" unless defined $result;
	return $result;
}

=pod

=head2 C<get_matches>

Parameters:

=over

=item * The text in which we need to search

=item * The regular expression

=item * The offset within the text where we the last match started so the next
forward match must start after this.

=item * The offset within the text where we the last match ended so the next
backward match must end before this.

=item * backward bit (1 = search backward, 0 = search forward) - Optional. Defaults to 0.

=back

=cut

sub get_matches {
	my ( $text, $regex, $from, $to, $backward ) = @_;
	die 'missing parameters' if @_ < 4;

	require Encode;
	$text  = Encode::encode( 'utf-8', $text );
	$regex = Encode::encode( 'utf-8', $regex );

	my @matches = ();
	while ( $text =~ /$regex/mg ) {
		my $e = pos($text);
		unless ( defined($1) ) {
			print STDERR 'WARNING (' . join( ",", map { $_ || ''; } ( caller(0) ) ) . "): $regex has no \$1 match\n";
			next;
		}
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

=head2 C<_T>

The C<_T> function is used for strings that you do not want to translate
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
	close $fh;

	# Find the first number after the first occurance of "dir".
	unless ( $buffer =~ /\bdir\b\s+(\d+)/m ) {
		return;
	}

	# Quote this to prevent certain aliasing bugs
	return "$1";
}





#####################################################################
# Shared Resources

=head2 C<share>

If called without a parameter returns the share directory of Padre.
If called with a parameter (e.g. C<Perl6>) returns the share directory
of L<Padre::Plugin::Perl6>. Uses File::ShareDir inside.

=cut

sub share {
	my $plugin = shift;

	if ( $ENV{PADRE_DEV} ) {
		my $root = File::Spec->rel2abs(
			File::Spec->catdir(
				$FindBin::Bin,
				File::Spec->updir,
				File::Spec->updir
			)
		);
		unless ($plugin) {
			return File::Spec->catdir( $root, 'Padre', 'share' );
		}

		# two cases: share in the Padre-Plugin-Name/share
		# or share in the Padre-Plugin-Name/lib/Padre/Plugin/Name/share directory
		my $plugin_dir = File::Spec->catdir( $root, "Padre-Plugin-$plugin", 'share' );
		if ( -d $plugin_dir ) {
			return $plugin_dir;
		}
		$plugin_dir = File::Spec->catdir( $root, "Padre-Plugin-$plugin", 'lib', 'Padre', 'Plugin', $plugin, 'share' );
		return $plugin_dir;
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

	# Rely on automatic handling of everything
	require File::ShareDir;
	if ($plugin) {
		return File::Spec->rel2abs( File::ShareDir::dist_dir("Padre-Plugin-$plugin") );
	} else {
		return File::Spec->rel2abs( File::ShareDir::dist_dir('Padre') );
	}
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
			my @files = readdir $dh;
			close $dh;
			foreach my $lang (@files) {
				next if $lang eq '.';
				next if $lang eq '..';
				if ( -e File::Spec->catfile( $dir, $lang, 'perldiag.pod' ) ) {
					$languages{$lang} = 1;
				}
			}
		}
	}
	my @tr = sort keys %languages;
	return @tr;
}

### DEPRECATED
sub get_project_rcs {
	if ( $VERSION > 0.84 ) {
		warn "Deprecated Padre::Util::get_project_rcs called by " . scalar caller();
	}
	require Padre::Current;
	my $manager = Padre::Current->ide->project_manager;
	my $project = $manager->from_root(shift) or return;
	return $project->vcs;
}

### DEPRECATED
sub get_project_dir {
	if ( $VERSION > 0.84 ) {
		warn "Deprecated Padre::Util::get_project_dir called by " . scalar caller();
	}
	require Padre::Current;
	my $file    = shift or return;
	my $manager = Padre::Current->ide->project_manager;
	my $project = $manager->from_file($file) or return;
	return $project->root;
}





######################################################################
# Logging and Debugging

sub humanbytes {

	my $Bytes = $_[0] || 0;

	eval { require Format::Human::Bytes; };
	return $Bytes if $@; # Doesn't look good, but works

	return Format::Human::Bytes::base2( $Bytes, 1 );

}

# Returns the memory currently used by this application:
sub process_memory {
	if (Padre::Constant::UNIX) {
		open my $meminfo, '<', '/proc/self/stat' or return;
		my $rv = ( split( / /, <$meminfo> ) )[22];
		close $meminfo;
		return $rv;
	} elsif (Padre::Constant::WIN32) {
		require Padre::Util::Win32;
		return Padre::Util::Win32::GetCurrentProcessMemorySize();
	}
	return;
}

1;

__END__

=pod

=head1 COPYRIGHT

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
