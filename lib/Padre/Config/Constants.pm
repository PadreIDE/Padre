#
# Constants used by various configuration systems.
#

package Padre::Config::Constants;

use File::Path            qw{ mkpath };
use File::Spec;
use File::Spec::Functions qw{ catdir catfile rel2abs };

# -- export stuff
use base qw{ Exporter };

my @dirs   = qw{ $PADRE_CONFIG_DIR $PADRE_PLUGIN_DIR    };
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


# -- list of constants

# files & dirs
our $PADRE_CONFIG_DIR = _find_padre_config_dir();
our $PADRE_PLUGIN_DIR = _find_padre_plugin_dir();
our $CONFIG_FILE_USER = catfile( $PADRE_CONFIG_DIR, 'config.yml' );
our $CONFIG_FILE_HOST = catfile( $PADRE_CONFIG_DIR, 'config.db'  );

# settings types (based on firefox)
our $BOOLEAN = 0;
our $POSINT  = 1;
our $INTEGER = 2;
our $ASCII   = 3;
our $PATH    = 4;

# settings stores
our $HOST    = 0;
our $HUMAN   = 1;
our $PROJECT = 2;


# -- private subs

#
# my $dir = _fond_padre_config_dir();
#
# find and return the config directory where padre should store its
# preferences & settings. no params.
#
sub _find_padre_config_dir {
	# define config dir
	my @subdirs;
	if ( defined $ENV{PADRE_HOME} ) {
		# PADRE_HOME env var set, always use unix style.
		@subdirs = ( $ENV{PADRE_HOME}, '.padre' );
	} else {
		# using data dir as defined by the os.
		@subdirs = ( File::HomeDir->my_data );
		push @subdirs, File::Spec->isa('File::Spec::Win32')
			? qw{ Perl Padre }	# on windows use the traditional vendor/product format
			: qw{ .padre };		# TODO - is mac correctly covered?
	}
	my $confdir = rel2abs( catdir( @subdirs ) );

	# check if directory exists, create it otherwise
	mkpath($confdir) or die "Cannot create config dir '$confdir' $!"
		unless -e $confdir;

	return $confdir;
}


#
# my $dir = _find_padre_plugin_dir();
#
# find and return the directory where padre should check the locally
# installed plugins. no params.
#
sub _find_padre_plugin_dir {
	my $pluginsdir = catdir( $PADRE_CONFIG_DIR, 'plugins' );

	# check if plugin directory exists, create it otherwise
	my $fullpath = catdir( $pluginsdir, 'Padre', 'Plugin'	);
	unless ( -e $fullpath ) {
		mkpath($fullpath) or
		die "Cannot create plugins dir '$fullpath': $!";
	}

	# copy the My Plugin if necessary
	my $file = catfile( $fullpath, 'My.pm' );
	unless ( -e $file ) {
		Padre::Config->copy_original_My_plugin( $file );
	}

	return $pluginsdir;
}


1;

__END__

=head1 NAME

Padre::Config::Constants - constants used by config subsystems


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

Imports C<$PADRE_CONFIG_DIR> and C<$PADRE_PLUGIN_DIR>.

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
