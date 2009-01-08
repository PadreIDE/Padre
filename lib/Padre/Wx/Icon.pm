package Padre::Wx::Icon;

# It turns out that icon management needs to be more complex than just
# a few utility functions in Padre::Wx, and that it needs an entire
# library of it's own.

# This library attempts to integrate padre with the freedesktop.org
# icon specifications using a highly limited and mostly
# wrong implementation of the algorithms they describe.
# http://standards.freedesktop.org/icon-naming-spec
# http://standards.freedesktop.org/icon-theme-spec

# Initially we only support the use of icons in directories bundled
# with Padre. Later, we'll probably be forced by distro-packagers and
# users to support integration with system icon themes.

use 5.008;
use strict;
use warnings;
use File::Spec  ();
use Padre::Util ();
use Padre::Wx   ();

our $VERSION = '0.24';

# For now apply a single common configuration
use constant SIZE    => '16x16';
use constant EXT     => '.png';
use constant THEMES  => ( 'gnome', 'tango', 'padre' );
use constant ICONS   => Padre::Util::sharedir('icons');

# Add a little meaning to the split hash keys
use constant CONTEXT => 0;
use constant NAME    => 1;





#####################################################################
# Icon Resolver

# For now, assume the people using this are competant and don't
# bother to check params.
# TODO: Clearly this assumption can't last...
sub find {
	my @param = split /\//, $_[0];

	# Search through the theme list
	foreach my $theme ( THEMES ) {
		my $file = File::Spec->catfile(
			ICONS,
			$theme,
			SIZE,
			$param[CONTEXT],
			($param[NAME] . EXT),
		);
		next unless -f $file;
		return Wx::Bitmap->new($file, Wx::wxBITMAP_TYPE_PNG );
	}

	return undef;
}

1;
