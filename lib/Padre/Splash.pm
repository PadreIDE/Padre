package Padre::Splash;

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.43';

# Load just enough modules to get Wx bootstrapped far enough
# to show the splash screen;
use Padre::Util ();
use Wx ();

unless ( $ENV{HARNESS_ACTIVE} ) {
	Wx::SplashScreen->new(
		Wx::Bitmap->new(
			Padre::Util::sharefile('padre-splash.bmp'),
			Wx::wxBITMAP_TYPE_BMP()
		),
		Wx::wxSPLASH_CENTRE_ON_SCREEN()
		| Wx::wxSPLASH_TIMEOUT(),
		3500, undef, -1
	);
}

1;
