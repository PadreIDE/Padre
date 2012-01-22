package Padre::Wx::Icon;

# It turns out that icon management needs to be more complex than just
# a few utility functions in Padre::Wx, and that it needs an entire
# library of its own.

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
use File::Spec   ();
use Params::Util ();
use Padre::Util  ();
use Padre::Wx    ();

our $VERSION = '0.94';

# For now apply a single common configuration
use constant SIZE   => '16x16';
use constant EXT    => '.png';
use constant THEMES => ( 'gnome218', 'padre' );
use constant ICONS  => Padre::Util::sharedir('icons');

# Supports the use of theme-specific "hints",
# when we want to substitute a technically incorrect
# icon on a theme by theme basis.
my %HINT = (
	'gnome218' => {},
);

# Lay down some defaults from our common
# constants
my %PREFS = (
	size  => SIZE,
	ext   => EXT,
	icons => ICONS,
);

our $DEFAULT_ICON_NAME = 'status/padre-fallback-icon';
our $DEFAULT_ICON;

# Convenience access to the official Padre icon
sub PADRE {
	return icon( 'logo', { size => '64x64' } );
}

# On windows, you actually need to provide it with a native icon file that
# contains multiple sizes so it can choose from it.
sub PADRE_ICON_FILE {
	my $ico = File::Spec->catfile( ICONS, 'padre', 'all', 'padre.ico' );
	return Wx::IconBundle->new($ico);
}




#####################################################################
# Icon Resolver

# Find an icon bitmap and convert to a real Wx::Icon in a single call
sub icon {
	my $image = find(@_);
	my $icon  = Wx::Icon->new;
	$icon->CopyFromBitmap($image);
	return $icon;
}

# For now, assume the people using this are competent
# and don't bother to check params.
# TO DO: Clearly this assumption can't last...
sub find {
	my $name  = shift;
	my $prefs = shift;

	# If you _really_ are competant ;),
	# prefer size, icons, ext
	# over the defaults
	my %pref =
		Params::Util::_HASH($prefs)
		? ( %PREFS, %$prefs )
		: %PREFS;

	# Search through the theme list
	foreach my $theme (THEMES) {
		my $hinted =
			( $HINT{$theme} and $HINT{$theme}->{$name} )
			? $HINT{$theme}->{$name}
			: $name;
		my $file = File::Spec->catfile(
			$pref{icons},
			$theme,
			$pref{size},
			( split /\//, $hinted )
		) . $pref{ext};
		next unless -f $file;
		return Wx::Bitmap->new( $file, Wx::BITMAP_TYPE_PNG );
	}

	if ( defined $DEFAULT_ICON ) {

		# fallback with a pretty ?
		return $DEFAULT_ICON;
	} elsif ( $name ne $DEFAULT_ICON_NAME ) {

		# setup and return the default icon
		$DEFAULT_ICON = find($DEFAULT_ICON_NAME);
		return $DEFAULT_ICON if defined $DEFAULT_ICON;
	}

	# THIS IS BAD!
	require Carp;

	# NOTE: This crash is mandatory. If you pass undef or similarly
	# wrong things to AddTool, you get a segfault and nobody likes
	# segfaults, right?
	Carp::confess("Could not find icon '$name'!");
}

# Some things like Wx::AboutDialogInfo want a _real_ Wx::Icon
sub cast_to_icon {
	my $icon = Wx::Icon->new;
	$icon->CopyFromBitmap(shift);
	return $icon;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
