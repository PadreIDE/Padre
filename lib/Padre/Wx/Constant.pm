package Padre::Wx::Constant;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.91';

# Read the sets of constants we care about
use Wx ( qw{
	wxCLRP_SHOW_LABEL
	wxCLRP_USE_TEXTCTRL
	wxCLRP_DEFAULT_STYLE
	wxDIRP_DIR_MUST_EXIST
	wxDIRP_CHANGE_DIR
	wxDIRP_USE_TEXTCTRL
	wxDIRP_DEFAULT_STYLE
	wxFLP_OPEN
	wxFLP_SAVE
	wxFLP_OVERWRITE_PROMPT
	wxFLP_FILE_MUST_EXIST
	wxFLP_CHANGE_DIR
	wxFLP_DEFAULT_STYLE
	wxFLP_USE_TEXTCTRL
	wxFNTP_USE_TEXTCTRL
	wxFNTP_DEFAULT_STYLE
	wxFNTP_FONTDESC_AS_LABEL
	wxFNTP_USEFONT_FOR_LABEL
	wxFNTP_MAXPOINT_SIZE
	wxLayout_Default
	wxLayout_LeftToRight
	wxLayout_RightToLeft
	wxMOD_NONE
	wxMOD_ALT
	wxMOD_CONTROL
	wxMOD_SHIFT
	wxMOD_WIN
	wxMOD_ALTGR
	wxMOD_META
	wxMOD_CMD
	wxMOD_ALL
	wxNOT_FOUND
	:aui
	:bitmap
	:button
	:checkbox
	:choicebook
	:clipboard
	:colour
	:combobox
	:comboctrl
	:control
	:datepicker
	:dialog
	:dirctrl
	:dnd
	:filedialog
	:font
	:frame
	:gauge
	:grid
	:html
	:hyperlink
	:icon
	:id
	:image
	:keycode
	:listbook
	:listbox
	:listctrl
	:locale
	:misc
	:menu
	:notebook
	:palette
	:panel
	:pen
	:progressdialog
	:radiobox
	:richtextctrl
	:sashwindow
	:scrollbar
	:scrolledwindow
	:sizer
	:slider
	:socket
	:spinbutton
	:splitterwindow
	:staticline
	:statusbar
	:stc
	:systemsettings
	:textctrl
	:timer
	:toolbar
	:toolbook
	:treectrl
	:window
	:wizard
} );

use constant TAGS => qw{
	wxMOD_NONE
	wxMOD_ALT
	wxMOD_CONTROL
	wxMOD_SHIFT
	wxMOD_WIN
	wxMOD_ALTGR
	wxMOD_META
	wxMOD_CMD
	wxMOD_ALL
	wxNOT_FOUND
	wxDefaultSize
	wxDefaultPosition
	:aui
	:clipboard
	:dialog
	:id
	:frame
	:sizer
	:systemsettings
	:textctrl
	:toolbar
	:toolbook
	:treectrl
};

sub load {
	my %constants = (
		THREADS => Wx::wxTHREADS,
		MOTIF   => Wx::wxMOTIF,
		MSW     => Wx::wxMSW,
		GTK     => Wx::wxGTK,
		MAC     => Wx::wxMAC,
		X11     => Wx::wxX11,
	);
	foreach my $function ( map { s/^:// ? @{$Wx::EXPORT_TAGS{$_}} : $_ } TAGS ) {
		next if defined $constants{$function};
		next unless $function =~ s/^wx//i;
		if ( exists $Wx::{$function} ) {
			warn "Clash with function Wx::$function";
			next;
		}
		if ( exists $Wx::{"${function}::"} ) {
			warn "Pseudoclash with namespace Wx::${function}::";
			next;
		}
		no strict 'refs';
		local $@;
		my $value = eval {
			&{"Wx::wx$function"}();
		};
		if ( $@ ) {
			# print "# Wx::wx$function failed to load\n";
			next;
		}
		unless ( defined $value ) {
			print "# Wx::wx$function is undefined\n";
			next;
		}
		$constants{$function} = $value;
	}

	# NOTE: This completes the conversion of Wx::wxFoo constants to Wx::Foo.
	# NOTE: On separate lines to prevent the PAUSE indexer thingkng that we
	#       are trying to claim ownership of Wx.pm
	package ## no critic
		Wx;
	require constant;
	constant::->import( \%constants );

	# Aliases for other things that aren't actual constants
	no warnings 'once';
	*Wx::TheApp = *Wx::wxTheApp;
}

load();

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
