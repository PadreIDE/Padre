package Padre::Constant;

# Constants used by various configuration systems.

use 5.008005;
use strict;
use warnings;
use Carp          ();
use File::Path    ();
use File::Spec    ();
use File::HomeDir ();

our $VERSION = '0.35';

# Setting Types (based on Firefox types)
use constant BOOLEAN => 0;
use constant POSINT  => 1;
use constant INTEGER => 2;
use constant ASCII   => 3;
use constant PATH    => 4;

# Setting Storage Backends
use constant HOST    => 0;
use constant HUMAN   => 1;
use constant PROJECT => 2;

# Files and Directories
use constant CONFIG_DIR => File::Spec->rel2abs(
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

use constant CONFIG_HUMAN => File::Spec->catfile( CONFIG_DIR, 'config.yml' );
use constant CONFIG_HOST  => File::Spec->catfile( CONFIG_DIR, 'config.db' );
use constant PLUGIN_DIR   => File::Spec->catdir( CONFIG_DIR, 'plugins' );
use constant PLUGIN_LIB   => File::Spec->catdir( PLUGIN_DIR, 'Padre', 'Plugin' );

# Check and create the directories that need to exist
unless ( -e CONFIG_DIR or File::Path::make_path(CONFIG_DIR) ) {
	Carp::croak("Cannot create config dir '" . CONFIG_DIR . "': $!");
}
unless ( -e PLUGIN_LIB or File::Path::make_path(PLUGIN_LIB) ) {
	Carp::croak("Cannot create plugins dir '" . PLUGIN_LIB . "': $!");
}

1;

__END__

=pod

=head1 NAME

Padre::Constant - constants used by config subsystems

=head1 SYNOPSIS

    use Padre::Constant qw{ :all };
    [...]
    # do stuff with exported constants

=head1 DESCRIPTION

Padre uses various configuration subsystems (see C<Padre::Config> for more
information). Those systems needs to somehow agree on some basic stuff, which
is defined in this module.

=head1 PUBLIC API

=head2 Available constants

This module exports nothing.

The list of available constants are:

=over 4

=item * BOOLEAN, POSINT, INTEGER, ASCII, PATH

Settings types.

=item * HOST, HUMAN, PROJECT

Settings stores.

=item * CONFIG_HOST

DB configuration file storing host settings.

=item * CONFIG_HUMAN

YAML configuration file storing user settings.

=item * CONFIG_DIR

Private Padre configuration directory Padre, used to store stuff.

=item * PLUGIN_DIR

Private directory where Padre can look for plugins.

=item * PLUGIN_LIB

Subdir of PLUGIN_DIR with the path C<Padre/Plugin> added
(or whatever depending on your platform) so that perl can
load a C<Padre::Plugin::> plugin.

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
