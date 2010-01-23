package Padre::Startup;

=pod

=head1 NAME

Padre::Startup::Config - Padre startup-related config settings

=head1 DESCRIPTION

Padre stores host-related data in a combination of an easily transportable
YAML file for personal settings and a powerful and robust SQLite-based
config database for host settings and state data.

Unfortunately, fully loading and validating these configurations can be
relatively expensive and may take some time. A limited number of these
settings need to be available extremely early in the Padre bootstrapping
process.

The F<startup.yml> file is automatically written at the same time as the
regular config files, and is read without validating during early startup.

B<Padre::Startup::Config> is a small convenience module for reading and
writing the F<startup.yml> file.

=head1 FUNCTIONS

=cut

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.55';





#####################################################################
# Splash Screen Support

my $SPLASH = undef;

# Shows Padre's splash screen if this is the first time
# It is saved as BMP as it seems (from wxWidgets documentation)
# that it is the most portable format (and we don't need to
# call Wx::InitAllImageHeaders() or whatever)
sub show_splash {
	return if $SPLASH;

	# Use CCNC version if it exists and fallback to boring splash
	# so that we can bundle it in Debian

	# Don't show the splash screen during testing otherwise
	# it will spoil the flashy surprise when they upgrade.
	unless ( $ENV{HARNESS_ACTIVE} or $ENV{PADRE_NOSPLASH} ) {

		# Load just enough modules to get Wx bootstrapped
		# to the point it can show the splash screen.
		require Padre::Util;
		require Wx;
		$SPLASH = Wx::SplashScreen->new(
			Wx::Bitmap->new(
				Padre::Util::splash(),
				Wx::wxBITMAP_TYPE_BMP()
			),
			Wx::wxSPLASH_CENTRE_ON_SCREEN() | Wx::wxSPLASH_TIMEOUT(),
			3500, undef, -1
		);
	}
}

# Destroy the splash screen if it exists
sub destroy_splash {
	if ($SPLASH) {
		$SPLASH->Destroy;
		$SPLASH = 1;
	}
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
