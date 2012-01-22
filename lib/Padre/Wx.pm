package Padre::Wx;

# Provides a set of Wx-specific miscellaneous functions

use 5.008;
use strict;
use warnings;
use constant        ();
use Params::Util    ();
use Padre::Constant ();
use Padre::Current  ();

# Threading must be loaded before Wx loads
use threads;
use threads::shared;

# Load every exportable constant into here, so that they come into
# existence in the Wx:: packages, allowing everywhere else in the code to
# use them without braces.
use Wx         ('wxTheClipboard');
use Wx::Event  (':everything');
use Wx::AUI    ();
use Wx::Socket ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.43';

BEGIN {

	# Hard version lock on a new-enough Wx.pm
	unless ( $Wx::VERSION and $Wx::VERSION >= 0.91 ) {
		die("Your Wx.pm is not new enough (need 0.91, found $Wx::VERSION)");
	}

	# Load all the image handlers that we support by default in Padre.
	# Don't load all of them with Wx::InitAllImageHandlers, it wastes memory.
	Wx::Image::AddHandler( Wx::PNGHandler->new );
	Wx::Image::AddHandler( Wx::ICOHandler->new );
	Wx::Image::AddHandler( Wx::XPMHandler->new );

	# Load the enhanced constants package
	require Padre::Wx::Constant;
}

# Some default Wx objects
use constant {
	DEFAULT_COLOUR => Wx::Colour->new( 0xFF, 0xFF, 0xFF ),
	NULL_FONT      => Wx::Font->new( Wx::NullFont ),
	EDITOR_FONT    => Wx::Font->new( 9, Wx::TELETYPE, Wx::NORMAL, Wx::NORMAL ),
};

sub import {
	my $class = shift;
	my @load  = grep { not $_->VERSION } map { "Wx::$_" } @_;
	if ( @load ) {
		local $@;
		eval join "\n", map { "require $_;" } @load;
		Padre::Wx::Constant::load();
	}
	return 1;
}





#####################################################################
# Wx Version Methods

sub version_perl {
	Wx::wxVERSION();
}

sub version_human {
	my $string = Wx::wxVERSION();
	$string =~ s/(\d\d\d)(\d\d\d)/$1.$2/;
	$string =~ s/\.0+(\d)/.$1/g;
	return $string;
}





#####################################################################
# Convenience Functions

# Colour constructor
sub color {
	my $string = shift;
	my @rgb    = ( 0xFF, 0xFF, 0xFF ); # Some default
	if ( not defined $string ) {

		# Carp::cluck("undefined color");
	} elsif ( $string =~ /^(..)(..)(..)$/ ) {
		@rgb = map { hex($_) } ( $1, $2, $3 );
	} else {

		# Carp::cluck("invalid color '$string'");
	}
	return Wx::Colour->new(@rgb);
}

# Font constructor
sub native_font {
	my $string = shift;
	unless ( defined Params::Util::_STRING($string) ) {
		return NULL_FONT;
	}

	# Attempt to apply the font string
	local $@;
	my $nfont = eval {
		my $font = Wx::Font->new( Wx::NullFont );
		$font->SetNativeFontInfoUserDesc($string);
		$font->IsOk ? $font : undef;
	};
        return $nfont if $nfont;
	return NULL_FONT;
}

# Telytype/editor font
sub editor_font {
	my $string = shift;
	unless ( defined Params::Util::_STRING($string) ) {
		return EDITOR_FONT;
	}

	# Attempt to apply the font string
	local $@;
	my $efont = eval {
		my $font = Wx::Font->new( 9, Wx::TELETYPE, Wx::NORMAL, Wx::NORMAL );
		$font->SetNativeFontInfoUserDesc($string);
		$font->IsOk ? $font : undef;
	};
	return $efont if $efont;
	return EDITOR_FONT;
}

# The Wx::AuiPaneInfo method-chaining API is stupid.
# This method provides a less insane way to create one.
sub aui_pane_info {
	my $class = shift;
	my $info  = Wx::AuiPaneInfo->new;
	while (@_) {
		my $method = shift;
		$info->$method(shift);
	}
	return $info;
}





#####################################################################
# External Website Integration

sub launch_browser {
	require Padre::Task::LaunchDefaultBrowser;
	Padre::Task::LaunchDefaultBrowser->new(
		url => $_[0],
	)->schedule;
}

# Launch a "Live Support" window on Mibbit.com or other service
sub launch_irc {
	my $channel = shift;

	# Generate the (long) chat URL
	my $url = "http://padre.perlide.org/irc.html?channel=$channel";
	if ( my $locale = Padre::Current->config->locale ) {
		$url .= "&locale=$locale";
	}

	# Spawn a browser to show it
	launch_browser($url);

	return;
}

# Launch a browser window for a local file
sub launch_file {
	require URI::file;
	launch_browser( URI::file->new_abs(shift) );
}





######################################################################
# Wx::Event Convenience Functions

# FIXME Find out why EVT_CONTEXT_MENU doesn't work on Ubuntu
if ( Padre::Constant::UNIX ) {
	*Wx::Event::EVT_CONTEXT = *Wx::Event::EVT_RIGHT_DOWN;
} else {
	*Wx::Event::EVT_CONTEXT = *Wx::Event::EVT_CONTEXT_MENU;
}

1;

=pod

=head1 NAME

Padre::Wx - Wx integration for Padre

=head1 DESCRIPTION

Support function library for Wx related things, and bootstrap logic for Wx integration.

Isolates any F<Wx.pm> twiddling away from the actual Padre implementation code.

Load every exportable constant, so that they come into
existence in the C<Wx::> packages, allowing everywhere else in the code to
use them without braces.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
