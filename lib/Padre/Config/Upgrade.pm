package Padre::Config::Upgrade;

# This module should do any tasks which are required to upgrade the config
# from and older version to the current (reading a config written on 0.47 in 0.48)

use 5.008;
use strict;
use warnings;
use Padre::Logger;

our $VERSION = '0.90';

=pod

=head1 NAME

Padre::Config::Upgrade - Upgrade a configuration file from an older version

=head1 DESCRIPTION

If you installed Padre 0.40 and now you upgrade to 0.47, there are many
new configuration items - which all have safe default values.

But there may also be some options which have been renamed or places where
one option has been split into two or more. This module deals with them,
it knows how to upgrade the configuration from one version to another.

=head1 PUBLIC METHODS

  $config->check;

This method does all the checks when being called on a L<Padre::Config> object.

=cut

sub check {
	my $self = shift;

	TRACE("Checking the need to upgrade the configuration") if DEBUG;
	foreach my $storage ( 'human', 'host' ) {
		unless ( defined $self->$storage->{Version} ) {

			# We have a pre-0.48 - config and this module starts
			# working at upgrades from 0.48 to higher versions.
			# This may be a new config or a upgrade from a
			# unsupported version, so just insert the new version
			$self->$storage->{Version} = $VERSION;
			next;
		}

		# Nothing to do if config is up-to-date
		next if $self->$storage->{Version} == $VERSION;

		# This is only a sample and should be replaced by the first
		# real usage of this module
		if ( $storage eq 'human' and $self->$storage->{Version} == 0.00 ) {

			# Call subs or methods here or write short upgrades in this
			# place.
			# Remember to check if upgrades from older versions work!

		} elsif ( $self->$storage->{Version} < 0.48 ) {

			# There is nothing which needs conversation when upgrading from a
			# config prior 0.48 to our current version, so just update the
			# config version number
			$self->$storage->{Version} = $VERSION;
		}
	}
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
