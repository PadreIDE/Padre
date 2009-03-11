#
# Configuration and state data relating to the human using Padre.
#

package Padre::Config::Human;

use 5.008;
use strict;
use warnings;

use Storable      qw{ dclone };
use YAML::Tiny    qw{ DumpFile LoadFile };
use Params::Util  qw{ _HASH0 };
use Padre::Config;

our $VERSION = '0.28';

my $SCHEMA_VERSION = 1;		# version of config schema


#
# my $config = Padre::Config::Human->read;
#
# load & return the user configuration from the yaml file. return undef in
# case of failure.
#
# no params.
#
sub read {
	my $class = shift;

	# Load the user configuration
	my $hash = eval {
		LoadFile(
			Padre::Config->default_yaml
		)
	};
	return unless _HASH0($hash);

	# Create and return the object
	return bless $hash, __PACKAGE__;
}

#
# $config->create;
#
# create & return an empty user configuration. (almost empty, since it will
# still store the version of the config schema - see version() below).
#
# no params.
#
sub create {
	my $class = shift;
	my $file  = Padre::Config->default_yaml;

	DumpFile( $file, {
		version => $SCHEMA_VERSION,
	} ) or Carp::croak("Failed to create '$file'");

	return $class->read;
}

#
# $config->write;
#
# (over-)write user configuration to the yaml file.
#
# no params.
#
sub write {
	my $self = shift;

	# Clone and remove the bless
	my $copy = dclone( +{ %$self } );

	# Save the user configuration
	DumpFile(
		Padre::Config->default_yaml,
		$copy,
	);

	return 1;
}

#
# my $version = $config->version;
#
# return the version of the config schema. indeed, we might want to have
# more structured config instead of a plain hash later on. note that this
# version is stored with the other user preferences at the same level.
#
# no params.
#
sub version {
	$_[0]->{version};
}

1;

__END__

=head1 NAME

Padre::Config::Human - Padre configuration storing personal preferences


=head1 DESCRIPTION

This class implements the personal preferences of Padre's users. See C<Padre::Config>
for more information on the various types of preferences supported by Padre.

All human settings are stored in a hash as top-level keys (no hierarchy). The hash is
then dumped in C<config.yml>, a YAML file in Padre's preferences directory (see
C<Padre::Config>). 


=head1 LICENSE & COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
