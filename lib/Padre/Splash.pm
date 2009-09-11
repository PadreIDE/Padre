package Padre::Splash;

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.46';

# Load just enough modules to get Wx bootstrapped far enough
# to show the splash screen;
use Padre::Util ();
use Wx          ();

unless ( $ENV{HARNESS_ACTIVE} or $ENV{PADRE_NOSPLASH} ) {
	Wx::SplashScreen->new(
		Wx::Bitmap->new(
			Padre::Util::sharefile('padre-splash.bmp'),
			Wx::wxBITMAP_TYPE_BMP()
		),
		Wx::wxSPLASH_CENTRE_ON_SCREEN() | Wx::wxSPLASH_TIMEOUT(),
		3500, undef, -1
	);
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
