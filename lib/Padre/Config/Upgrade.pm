#
# This module should do any tasks which are required to upgrade the config
# from and older version to the current (reading a config written on 0.47 in 0.48)
#

package Padre::Config::Upgrade;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.48';


=head1 NAME

Padre::Config::Upgrade - Upgrade a config file from an older version


=head1 DESCRIPTION

If you installed Padre 0.40 and noew you upgrade to 0.47, there are many
noew config items - which all have safe default values.

But there may also be some options which have been renamed or places where
one option has been splitted into two or more. This module deals with them,
it knows how to upgrade the config from one version to another.

=head1 PUBLIC METHODS

	$config->check;

This method does all the checks when being called on a Padre::Config object.

=cut

sub check {
	my $self = shift;

	for my $storage ( 'human', 'host' ) {

		if ( !defined( $self->$storage->{Version} ) ) {

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
		if ( ( $storage eq 'human' ) and ( $self->$storage->{Version} == 0.47 ) ) {

			# Call subs or methods here or write short upgrades in this
			# place.
			# Remember to check if upgrades from older versions work!
		}
	}
}

1;

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut


# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
