package Padre::Config::Constants;

# Constants used by various configuration systems.

use strict;
use warnings;
use Exporter      ();
use File::Path    ();
use File::Spec    ();
use File::HomeDir ();

# Regular Globals
our $VERSION = '0.35';
our @ISA     = 'Exporter';

# Export Globals
my @dirs   = qw{ $PADRE_CONFIG_DIR $PADRE_PLUGIN_DIR $PADRE_PLUGIN_LIBDIR };
my @files  = qw{ $CONFIG_FILE_HOST $CONFIG_FILE_USER    };
my @stores = qw{ $HOST $HUMAN $PROJECT                  };
my @types  = qw{ $BOOLEAN $POSINT $INTEGER $ASCII $PATH };

our @EXPORT_OK   = ( @dirs, @files, @stores, @types );
our %EXPORT_TAGS = (
	dirs   => \@dirs,
	files  => \@files,
	stores => \@stores,
	types  => \@types,
);

# Setting Types (based on firefox)
our $BOOLEAN = 0;
our $POSINT  = 1;
our $INTEGER = 2;
our $ASCII   = 3;
our $PATH    = 4;

# Settings Stores
our $HOST    = 0;
our $HUMAN   = 1;
our $PROJECT = 2;

# Files and Directories
our $PADRE_CONFIG_DIR = File::Spec->rel2abs(
	File::Spec->catdir(
		defined($ENV{PADRE_HOME})
			? ( $ENV{PADRE_HOME}, '.padre' )
			: (
				File::HomeDir->my_data,
				File::Spec->isa('File::Spec::Win32')
					? qw{ Perl Padre }
					: qw{ .padre }
			)
	)
);

our $PADRE_PLUGIN_DIR    = File::Spec->catdir(  $PADRE_CONFIG_DIR, 'plugins' );
our $PADRE_PLUGIN_LIBDIR = File::Spec->catdir(  $PADRE_PLUGIN_DIR, 'Padre', 'Plugin' );
our $CONFIG_FILE_USER    = File::Spec->catfile( $PADRE_CONFIG_DIR, 'config.yml' );
our $CONFIG_FILE_HOST    = File::Spec->catfile( $PADRE_CONFIG_DIR, 'config.db' );

# Check and create the directories that need to exist
unless ( -e $PADRE_CONFIG_DIR ) {
	File::Path::mkpath($PADRE_CONFIG_DIR)
	or die("Cannot create config dir '$PADRE_CONFIG_DIR': $!");
}
unless ( -e $PADRE_PLUGIN_LIBDIR ) {
	File::Path::mkpath( $PADRE_PLUGIN_LIBDIR )
	or die("Cannot create plugins dir '$PADRE_PLUGIN_LIBDIR': $!");
}

1;

__END__

=pod

=head1 NAME

Padre::Config::Constants - constants used by config subsystems

=head1 SYNOPSIS

    use Padre::Config::Constants qw{ :all };
    [...]
    # do stuff with exported constants

=head1 DESCRIPTION

Padre uses various configuration subsystems (see C<Padre::Config> for more
information). Those systems needs to somehow agree on some basic stuff, which
is defined in this module.

=head1 PUBLIC API

=head2 Available constants

This module exports nothing by default. However, some constants can
be imported with:

    use Padre::Config::Constants qw{ $FOO $BAR };

The list of available constants are:

=over 4

=item * $BOOLEAN, $POSINT, $INTEGER, $ASCII, $PATH

Settings types.

=item * $HOST, $HUMAN, $PROJECT

Settings stores.

=item * $CONFIG_FILE_HOST

DB configuration file storing host settings.

=item * $CONFIG_FILE_USER

YAML configuration file storing user settings.

=item * $PADRE_CONFIG_DIR

Private Padre configuration directory Padre, used to store stuff.

=item * $PADRE_PLUGIN_DIR

Private directory where Padre can look for plugins.

=item * $PADRE_PLUGIN_LIBDIR

Subdir of $PADRE_PLUGIN_DIR with the path C<Padre/Plugin> added (or whatever
depending on your platform) so that perl can load a C<Padre::Plugin::> plugin.

=back

=head2 Available group of constants

Since lots of constants are somehow related, this module defines some tags
to import them all at once, with eg:

    use Padre::Config::Constants qw{ :dirs };

The tags available are:

=over 4

=item * all

Imports everything.

=item * dirs

Imports C<$PADRE_CONFIG_DIR>, C<$PADRE_PLUGIN_DIR> and C<$PADRE_PLUGIN_LIBDIR>.

=item * files

Imports C<$CONFIG_FILE_HOST> and C<$CONFIG_FILE_USER>.

=item * stores

Imports C<$BOOLEAN>, C<$POSINT>, C<$INTEGER>, C<$ASCII> and C<$PATH>.

=item * types

Imports C<$HOST>, C<$HUMAN> and C<$PROJECT>.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
