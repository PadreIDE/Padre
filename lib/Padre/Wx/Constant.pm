package Padre::Wx::Constant;

use 5.008;
use strict;
use warnings;
use constant ();
use Wx       ();

our $VERSION = '0.91';

# Scan for all of the Wx::wxFOO AUTOLOAD functions and
# check that we can create Wx::FOO constants.
my $n         = 0;
my %constants = ();
foreach my $function ( sort map { /^wx([A-Z].+)$/ ? $1 : () } keys %Wx:: ) {
	next if $function eq 'VERSION';
	next if $function =~ /^Log[A-Z]/;
	next unless $function eq uc($function);
	next unless Wx->can("wx$function");
	if ( exists $Wx::{$function} ) {
		warn "Clash with function Wx::$function";
		next;
	}
	if ( exists $Wx::{"${function}::"} ) {
		warn "Pseudoclash with namespace Wx::${function}::";
		next;
	}
	my $error = 0;
	my $value = Wx::constant( "wx$function", 0, $error );
	if ( $error ) {
		# print STDERR ++$n . ": Failed to load constant wx$function\n";
		next;
	}
	$constants{$function} = $value;
}

# Convert to proper constants
# NOTE: This completes the conversion of Wx::wxFoo constants to Wx::Foo.
# NOTE: On separate lines to prevent the PAUSE indexer thingkng that we
#       are trying to claim ownership of Wx.pm
SCOPE: {
	package ## no critic
		Wx;
	constant::->import( \%constants );
	constant::->import( {
		GTK            => Wx::wxGTK,
		MAC            => Wx::wxMAC,
		MSW            => Wx::wxMSW,
		THREADS        => Wx::wxTHREADS,
		VERSION_STRING => Wx::wxVERSION_STRING,
		X11            => Wx::wxX11,
	} );
}

no warnings 'once';

# Aliases for other things that aren't actual constants
*Wx::NullAcceleratorTable = *Wx::wxNullAcceleratorTable;
*Wx::NullAnimation        = *Wx::wxNullAnimation;
*Wx::NullBitmap           = *Wx::wxNullBitmap;
*Wx::NullColour           = *Wx::wxNullColour;
*Wx::NullCursor           = *Wx::wxNullCursor;
*Wx::NullFont             = *Wx::wxNullFont;
*Wx::NullIcon             = *Wx::wxNullIcon;
*Wx::NullPalette          = *Wx::wxNullPalette;
*Wx::NullPen              = *Wx::wxNullPen;
*Wx::DefaultPosition      = *Wx::wxDefaultPosition;
*Wx::DefaultSize          = *Wx::wxDefaultSize;
*Wx::DefaultValidator     = *Wx::wxDefaultValidator;
*Wx::TheApp               = *Wx::wxTheApp;
*Wx::TheClipboard         = *Wx::wxTheClipboard;

1;
