#
# Configuration and state data related to the host that Padre is running on.
#

package Padre::Config::Host;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.49';

# -- constructors

#
# my $config = Padre::Config::Host->_new( $href );
#
# create & return a new config object. if $href is not supplied, the config
# object will be empty. this constructor is private and should not be used
# outside this class.
#
sub _new {
	my ( $class, $href ) = @_;
	$href ||= {};
	bless $href, $class;
	return $href;
}

#
# my $config = Padre::Config::Host->read;
#
sub read {
	my $class = shift;

	# Read in the config data
	require Padre::DB;
	my %hash = map { $_->name => $_->value } Padre::DB::HostConfig->select;

	# Create and return the object
	return $class->_new( \%hash );
}

# -- public methods

#
# my $revision = $config->version;
#
sub version {
	my $self = shift;
	$self->{version}; # stored as other preferences!
}

#
# $config->write;
#
sub write {
	my $self = shift;
	require Padre::DB;

	Padre::DB->begin;
	Padre::DB::HostConfig->truncate;
	foreach my $name ( sort keys %$self ) {
		Padre::DB::HostConfig->create(
			name  => $name,
			value => $self->{$name},
		);
	}
	Padre::DB->commit;

	return 1;
}

1;

__END__

=head1 NAME

Padre::Config::Host - Padre configuration storing host state data


=head1 DESCRIPTION

This class implements the state data of the host on which Padre is running.
See C<Padre::Config> for more information on the various types of preferences
supported by Padre.

All those state data are stored in a database managed with C<Padre::DB>.
Refer to this module for more information on how this works.


=head1 PUBLIC API

=head2 Constructors

=over 4

=item my $config = Padre::Config::Host->read;

Load & return the host configuration from the database. Return undef in
case of failure.

No params.


=back


=head2 Object methods

=over 4

=item my $revision = $config->version;

Return the config schema revision. Indeed, we might want to change the
underlying storage later on.

No params.


=item $config->write;

(Over-)write host configuration to the database.

No params.

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
