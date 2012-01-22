package Padre::Constant;

# Constants used by various configuration systems.

use 5.008005;
use strict;
use warnings;
use Carp       ();
use File::Path ();
use File::Spec ();
use File::HomeDir 0.91 ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.57';

# Convenience constants for the operating system
use constant WIN32 => !!( ( $^O eq 'MSWin32' ) or ( $^O eq 'cygwin' ) );
use constant MAC => !!( $^O eq 'darwin' );
use constant UNIX => !( WIN32 or MAC );

# The local newline type
use constant {
	NEWLINE => {
		MSWin32 => 'WIN',
		MacOS   => 'MAC',
		dos     => 'WIN',

		# EBCDIC's NEL-char is currently not supported in Padre:
		#		os390     EBCDIC
		#		os400     EBCDIC
		#		posix-bc  EBCDIC
		#		vmesa     EBCDIC
		# Some other unsupported options:
		#		VMS       VMS
		#		VOS       VOS
		#		riscos    RiscOS
		#		amigaos   Amiga
		#		mpeix     MPEiX
		}->{$^O}

		# These will run fine using the default:
		# aix, bsdos, dgux, dynixptx, freebsd, linux, hpux, irix, darwin (MacOS-X),
		# machten, next, openbsd, netbsd, dec_osf, svr4, svr5, sco_sv, unicos, unicosmk,
		# solaris, sunos, cygwin, os2
		|| 'UNIX'
};

# Setting Types (based on Firefox types)
use constant {
	BOOLEAN => 0,
	POSINT  => 1,
	INTEGER => 2,
	ASCII   => 3,
	PATH    => 4,
};

# Setting Storage Backends
use constant {
	HOST    => 0,
	HUMAN   => 1,
	PROJECT => 2,
};

# Scintilla Margin Allocation
use constant {
	MARGIN_LINE   => 0,
	MARGIN_MARKER => 1,
	MARGIN_FOLD   => 2,
};

# Scintilla Marker Allocation
# The markers will be layered on top of each other with the highest
# value sitting topmost on any resulting stack of markers.
use constant {
	MARKER_WARN          => 1,
	MARKER_ERROR         => 2,
	MARKER_ADDED         => 3, # Line added
	MARKER_CHANGED       => 4, # Line changed
	MARKER_DELETED       => 5, # Line deleted
	MARKER_LOCATION      => 6, # current location of the debugger
	MARKER_BREAKPOINT    => 7, # location of the debugger breakpoint
	MARKER_NOT_BREAKABLE => 8, # location of the debugger not break able
};

# Scintilla Indicator Allocation
use constant {
	INDICATOR_SMART_HIGHLIGHT => 0,
	INDICATOR_WARNING         => 1,
	INDICATOR_ERROR           => 2,
	INDICATOR_UNDERLINE       => 3,
};

# Scintilla Syntax Highlighter Colours.
# NOTE: It's not clear why these need "PADRE_" in the name, but they do.
use constant {
	PADRE_BLACK        => 0,
	PADRE_BLUE         => 1,
	PADRE_RED          => 2,
	PADRE_GREEN        => 3,
	PADRE_MAGENTA      => 4,
	PADRE_ORANGE       => 5,
	PADRE_DIM_GRAY     => 6,
	PADRE_CRIMSON      => 7,
	PADRE_BROWN        => 8,
	PADRE_DIFF_HEADER  => 123,
	PADRE_DIFF_DELETED => 124,
	PADRE_DIFF_ADDED   => 125,
	PADRE_WARNING      => 126,
	PADRE_ERROR        => 127,
};

# Version Control System (VCS) constants
use constant {
	SUBVERSION => 'SVN',
	GIT        => 'Git',
	MERCURIAL  => 'Mercurial',
	BAZAAR     => 'Bazaar',
	CVS        => 'CVS',
};

# Portable Perl Support
use constant PORTABLE => do {
	no warnings 'once';
	$Portable::ENABLED and Portable->default->dist_root;
};

# Padre's home dir
use constant PADRE_HOME => $ENV{PADRE_HOME};

# Files and Directories
use constant CONFIG_DIR => File::Spec->rel2abs(
	File::Spec->catdir(
		defined( $ENV{PADRE_HOME} ) ? ( $ENV{PADRE_HOME}, '.padre' )
		: ( File::HomeDir->my_data,
			File::Spec->isa('File::Spec::Win32') ? qw{ Perl Padre }
			: qw{ .padre }
		)
	)
);

use constant LOG_FILE => File::Spec->catfile( CONFIG_DIR, 'debug.log' );
use constant PLUGIN_DIR => File::Spec->catdir( CONFIG_DIR, 'plugins' );
use constant PLUGIN_LIB => File::Spec->catdir( PLUGIN_DIR, 'Padre', 'Plugin' );
use constant CONFIG_HOST    => File::Spec->catfile( CONFIG_DIR, 'config.db' );
use constant CONFIG_HUMAN   => File::Spec->catfile( CONFIG_DIR, 'config.yml' );
use constant CONFIG_STARTUP => File::Spec->catfile( CONFIG_DIR, 'startup.txt' );

# Do initialisation in a function so we can run it again later if needed.
# Check and create the directories that need to exist.
sub init {
	unless ( -e CONFIG_DIR or File::Path::mkpath(CONFIG_DIR) ) {
		Carp::croak( "Cannot create config directory '" . CONFIG_DIR . "': $!" );
	}
	unless ( -e PLUGIN_LIB or File::Path::mkpath(PLUGIN_LIB) ) {
		Carp::croak( "Cannot create plug-ins directory '" . PLUGIN_LIB . "': $!" );
	}
}

BEGIN {
	init();
}





#####################################################################
# Config Defaults Needed At Startup

# Unlike on Linux, on Windows there's not really
# any major reason we should avoid the single-instance
# server by default.
# However during tests or in the debugger we need to make
# sure we don't accidentally connect to a running
# system-installed Padre while running the test suite.
# NOTE: The only reason this is here is that it is needed both during
# main configuration, and also during Padre::Startup.
use constant DEFAULT_SINGLEINSTANCE => ( WIN32 and not( $ENV{HARNESS_ACTIVE} or $^P ) ) ? 1 : 0;

# It would be better if we had fully dynamic collision awareness support,
# so that Padre could automatically port hop.
# In the mean time, just make sure that dev, test, and production versions
# of Padre use different ports, so they don't collide with each other.
use constant DEFAULT_SINGLEINSTANCE_PORT => (
	  $ENV{PADRE_DEV}      ? 4446
	: $ENV{HARNESS_ACTIVE} ? 4445
	: 4444
);

1;

__END__

=pod

=head1 NAME

Padre::Constant - constants used by configuration subsystems

=head1 SYNOPSIS

    use Padre::Constant ();
    [...]
    # do stuff with exported constants

=head1 DESCRIPTION

Padre uses various configuration subsystems (see C<Padre::Config> for more
information). Those systems needs to somehow agree on some basic stuff, which
is defined in this module.

=head1 CONSTANTS

=head2 C<WIN32>, C<MAC>, C<UNIX>

Operating Systems.

=head2 C<BOOLEAN>, C<POSINT>, C<INTEGER>, C<ASCII>, C<PATH>

Settings data types (based on Firefox types).

=head2 C<HOST>, C<HUMAN>, C<PROJECT>

Settings storage back-ends.

=head2 C<PADRE_REVISION>

The SVN Revision (when running a development build).

=head2 C<PADRE_BLACK>, C<PADRE_BLUE>, C<PADRE_RED>, C<PADRE_GREEN>, C<PADRE_MAGENTA>, C<PADRE_ORANGE>,
C<PADRE_DIM_GRAY>, C<PADRE_CRIMSON>, C<PADRE_BROWN>, C<PADRE_WARNING>, C<PADRE_ERROR>

Core supported colours.

=head2 C<CONFIG_HOST>

DB configuration file storing host settings.

=head2 C<CONFIG_HUMAN>

YAML configuration file storing user settings.

=head2 C<CONFIG_DIR>

Private Padre configuration directory Padre, used to store stuff.

=head2 C<PLUGIN_DIR>

Private directory where Padre can look for plug-ins.

=head2 C<PLUGIN_LIB>

Subdirectory of C<PLUGIN_DIR> with the path C<Padre/Plugin> added
(or whatever depending on your platform) so that Perl can
load a C<Padre::Plugin::> plug-in.

=head2 C<LOG_FILE>

Path and name of Padre's log file.

=head2 C<NEWLINE>

Newline style (UNIX, WIN or MAC) on the currently used operating system.

=head1 COPYRIGHT & LICENSE

Copyright 2008 - 2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
