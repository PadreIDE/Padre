package Padre::Splash;

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.49';

# Load just enough modules to get Wx bootstrapped far enough
# to show the splash screen;
use Padre::Util ();
use Wx          ();

my $SPLASH = undef;

#
# Shows Padre's splash screen if this is the first time
# It is saved as BMP as it seems (from wxWidgets documentation)
# that it is the most portable format (and we don't need to
# call Wx::InitAllImageHeaders() or whatever)
#
# Load the splash screen here, before we get bogged
# down running the database migration scripts.
# TODO
# This means we'll splash even if we run the single
# instance server, but that's better than before.
# We need it to be even less whacked.
#
sub show {
	return if $SPLASH;

	# use CCNC version if it exists and fallback to boring splash
	# so that we can bundle it in Debian

	# Don't show the splash screen during testing otherwise
	# it will spoil the flashy surprise when they upgrade.
	unless ( $ENV{HARNESS_ACTIVE} or $ENV{PADRE_NOSPLASH} ) {
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

#
# Destroy the splash screen if it exists
#
sub destroy {
	if ($SPLASH) {
		$SPLASH->Destroy;
		$SPLASH = 1;
	}
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
