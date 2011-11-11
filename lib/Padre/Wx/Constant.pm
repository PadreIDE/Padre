package Padre::Wx::Constant;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.92';

use constant WANT => qw{
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
	:bookctrl
	:brush
	:checkbox
	:choicebook
	:clipboard
	:collapsiblepane
	:colour
	:combobox
	:comboctrl
	:constraints
	:control
	:dc
	:dialog
	:dirctrl
	:dirdialog
	:dnd
	:filedialog
	:font
	:frame
	:gauge
	:html
	:hyperlink
	:icon
	:id
	:image
	:imagelist
	:keycode
	:layout
	:listbook
	:listbox
	:listctrl
	:locale
	:menu
	:miniframe
	:misc
	:notebook
	:ownerdrawncombobox
	:palette
	:panel
	:pen
	:power
	:process
	:progressdialog
	:radiobox
	:radiobutton
	:richtextctrl
	:sashwindow
	:scrollbar
	:scrolledwindow
	:sizer
	:slider
	:socket
	:spinbutton
	:spinctrl
	:splitterwindow
	:staticline
	:statictext
	:statusbar
	:systemsettings
	:textctrl
	:timer
	:toolbar
	:toplevelwindow
	:treectrl
	:window
};

# Read the sets of constants we care about
use Wx WANT, ':stc';

sub load {
	my %constants = (
		THREADS => Wx::wxTHREADS,
		MOTIF   => Wx::wxMOTIF,
		MSW     => Wx::wxMSW,
		GTK     => Wx::wxGTK,
		MAC     => Wx::wxMAC,
		X11     => Wx::wxX11,
	);
	foreach ( keys %constants ) {
		# Prevent duplicates on 2nd or later runs
		delete $constants{$_} if Wx->can($_);
	}
	foreach ( map { s/^:// ? @{ $Wx::EXPORT_TAGS{$_} } : $_ } WANT ) {
		next if defined $constants{$_};
		next unless s/^(wx)(.+)//i;
		my $wx   = $1;
		my $name = $2;
		if ( $name =~ /^EVT_/ ) {

			# We don't need event constants in Perl
			next;
		}
		if ( Wx->can($name) ) {
			# warn "Clash with function Wx::$name";
			next;
		}
		if ( exists $Wx::{"$name\::"} ) {
			warn "Pseudoclash with namespace Wx::$name\::";
			next;
		}
		no strict 'refs';
		local $@;
		my $value = eval { &{"Wx::$wx$name"}(); };
		if ($@) {

			# print "# Wx::wx$name failed to load\n";
			next;
		}
		unless ( defined $value ) {
			print "# Wx::$wx$name is undefined\n";
			next;
		}
		$constants{$name} = $value;
	}

	# NOTE: This completes the conversion of Wx::wxFoo constants to Wx::Foo.
	# NOTE: On separate lines to prevent the PAUSE indexer thingkng that we
	#       are trying to claim ownership of Wx.pm
	package ## no critic
		Wx;
	require constant;
	constant::->import( \%constants );
}

load();

# Aliases for other things that aren't actual constants
no warnings 'once';
*Wx::TheApp = *Wx::wxTheApp;

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
