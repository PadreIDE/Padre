package Padre::Config::Human;

=pod

=head1 NAME

Padre::Config::Human - Padre configuration for personal preferences

=head1 DESCRIPTION

This class implements the personal preferences of Padre's users. See L<Padre::Config>
for more information on the various types of preferences supported by Padre.

All human settings are stored in a hash as top-level keys (no hierarchy). The hash is
then dumped in F<config.yml>, a L<YAML> file in Padre's preferences directory (see
L<Padre::Config>).

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Scalar::Util    ();
use Storable        ();
use YAML::Tiny      ();
use Params::Util    ();
use Padre::Constant ();

our $VERSION = '1.02';

=pod

=head2 create

    my $config = Padre::Config::Human->create;

Create and return an empty user configuration. (Almost empty, since it will
still store the configuration schema revision - see L</"version">).

No parameters.

=cut

sub create {
	my $class = shift;
	my $self = bless {}, $class;
	$self->write;
	return $self;
}

=pod

=head2 read

    my $config = Padre::Config::Human->read;

Load & return the user configuration from the YAML file. Return C<undef> in
case of failure.

No parameters.

=cut

sub read {
	my $class = shift;

	# Load the user configuration
	my $hash = {};
	if ( -e Padre::Constant::CONFIG_HUMAN ) {
		$hash = eval { YAML::Tiny::LoadFile(Padre::Constant::CONFIG_HUMAN); };
	}
	unless ( Params::Util::_HASH0($hash) ) {
		return;
	}

	# Create and return the object
	return bless $hash, $class;
}

=head2 write

    $config->write;

(Over-)write user configuration to the YAML file.

No parameters.

=cut

sub write {
	my $self = shift;

	# Save the unblessed clone of the user configuration hash
	YAML::Tiny::DumpFile(
		Padre::Constant::CONFIG_HUMAN,
		$self->as_hash,
	);

	return 1;
}

=pod

=head2 clone

    my $object = $config->clone;

Creates a cloned copy of the configuration object.

=cut

sub clone {
	my $self  = shift;
	my $class = Scalar::Util::blessed($self);
	return bless {%$self}, $class;
}

=pod

=head2 as_hash

    my $hash = $config->as_hash;

Creates a cloned copy of the configuration object as a plain hash reference.

=cut

sub as_hash {
	my $self = shift;
	return Storable::dclone( +{ %$self } );
}

1;

__END__

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2016 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
