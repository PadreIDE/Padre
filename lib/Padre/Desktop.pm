package Padre::Desktop;

=pod

=head1 NAME

Padre::Desktop - Support library for Padre desktop integration

=head1 DESCRIPTION

This module provides a collection of functionality related to operating
system integration. It is intended to serve as a repository for code
relating to file extensions, desktop shortcuts, and so on.

This module is intended to be loadable without having to load the
main Padre code tree.

The workings of this module are currently undocumented.

=cut

use 5.008005;
use strict;
use warnings;
use File::Spec      ();
use Padre::Constant ();

our $VERSION = '0.51';

sub desktop {
	if (Padre::Constant::WXWIN32) {

		# NOTE: Convert this to use Win32::TieRegistry
#		require File::Temp;
#		my ( $reg, $regfile ) = File::Temp::tempfile( SUFFIX => '.reg' );
#		print $reg <<'REG';
#Windows Registry Editor Version 5.00
#
#[HKEY_CLASSES_ROOT\*\shell\Edit with Padre]
#
#[HKEY_CLASSES_ROOT\*\shell\Edit with Padre\Command]
#@="c:\\strawberry\\perl\\bin\\padre.exe \"%1\""
#REG
#		close $reg;

		# Create Padre's Desktop Shortcut
		require File::HomeDir;
		my $padre_lnk = File::Spec->catfile(
			File::HomeDir->my_desktop,
			'Padre.lnk',
		);
		return 1 if -f $padre_lnk;		

		# NOTE: Use Padre::Perl to make this distribution agnostic
		require Win32::Shortcut;
		my $link = Win32::Shortcut->new;
		$link->{Description}      = "Padre - The Perl IDE";
		$link->{Path}             = "C:\\strawberry\\perl\\bin\\padre.exe";
		$link->{WorkingDirectory} = "C:\\strawberry\\perl\\bin";

		$link->Save( $padre_lnk );
		$link->Close;

		return 1;
	}

	if (Padre::Constant::WXGTK) {

		# Create Padre.desktop launcher on KDE/gnome
		require Padre::Util;
		my $filename = "$ENV{HOME}/Desktop/Padre.desktop";
		my $logo     = Padre::Util::sharedir('icons/padre/64x64/logo.png');
		my $content  = <<"DESKTOP";
[Desktop Entry]
Name=Padre
Comment=Padre - The Perl IDE
Exec=/usr/local/bin/padre
Icon=$logo
Terminal=false
Type=Application
Categories=Development;Utility;
MimeType=text/plain;application/x-perl;application/x-perl6;
DESKTOP
		open my $fh, ">", $filename or die "Cannot create $filename: $!\n";
		print $fh $content;
		close $fh;

		return 1;
	}

	return 0;
}

1;

__END__

=pod

=head1 COPYRIGHT

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
