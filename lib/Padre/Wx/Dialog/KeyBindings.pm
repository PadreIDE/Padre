package Padre::Wx::Dialog::KeyBindings;

use 5.008;
use strict;
use warnings;
use Padre::Constant            ();
use Padre::Config              ();
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();

our $VERSION = '0.60';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};

=pod

=head1 NAME

Padre::Wx::Dialog::KeyBindings - a dialog to show and configure key bindings

=head1 DESCRIPTION

This dialog lets the user search for a key binding and then configure a new
shortcut if needed

=head1 PUBLIC API

=head2 C<new>

  my $advanced = Padre::Wx::Dialog::KeyBindings->new($main);

Returns a new C<Padre::Wx::Dialog::KeyBindings> instance

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Key Bindings') . ' (Work in progress... Not finished)',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Minimum dialog size
	$self->SetMinSize( [ 517, 550 ] );

	# Create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	# Create the controls
	$self->_create_controls($sizer);

	# Bind the control events
	$self->_bind_events;

	# Wrap everything in a vbox to add some padding
	$self->SetSizer($sizer);
	$self->Fit;
	$self->CentreOnParent;

	return $self;
}

# Create dialog controls
sub _create_controls {
	my ( $self, $sizer ) = @_;

	# Filter label
	my $filter_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Filter:') );

	# Filter text field
	$self->{filter} = Wx::TextCtrl->new( $self, -1, '' );

	# Filtered key bindings list
	$self->{list} = Wx::ListView->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL,
	);
	$self->{list}->InsertColumn( 0, Wx::gettext('Key binding name') );
	$self->{list}->InsertColumn( 1, Wx::gettext('Shortcut') );
	$self->{list}->InsertColumn( 2, Wx::gettext('Action') );

	# Shortcut label
	my $shortcut_label = Wx::StaticText->new( $self, -1, Wx::gettext('Sh&ortcut:') );

	# modifier radio button fields
	$self->{ctrl}  = Wx::CheckBox->new( $self, -1, 'CTRL' );
	$self->{alt}   = Wx::CheckBox->new( $self, -1, 'ALT' );
	$self->{shift} = Wx::CheckBox->new( $self, -1, 'Shift' );

	# + labels
	my $plus_label_1 = Wx::StaticText->new( $self, -1, '+' );
	my $plus_label_2 = Wx::StaticText->new( $self, -1, '+' );

	# key choice list
	my %keymap = (
		'00None'      => -1,
		'01Backspace' => Wx::WXK_BACK,
		'02Tab'       => Wx::WXK_TAB,
		'03Space'     => Wx::WXK_SPACE,
		'04Up'        => Wx::WXK_UP,
		'05Down'      => Wx::WXK_DOWN,
		'06Left'      => Wx::WXK_LEFT,
		'07Right'     => Wx::WXK_RIGHT,
		'08Insert'    => Wx::WXK_INSERT,
		'09Delete'    => Wx::WXK_DELETE,
		'10Home'      => Wx::WXK_HOME,
		'11End'       => Wx::WXK_END,
		'12Page up'   => Wx::WXK_PAGEUP,
		'13Page down' => Wx::WXK_PAGEDOWN,
		'14Enter'     => Wx::WXK_RETURN,
		'15Escape'    => Wx::WXK_ESCAPE,
		'21Numpad 0'  => Wx::WXK_NUMPAD0,
		'22Numpad 1'  => Wx::WXK_NUMPAD1,
		'23Numpad 2'  => Wx::WXK_NUMPAD2,
		'24Numpad 3'  => Wx::WXK_NUMPAD3,
		'25Numpad 4'  => Wx::WXK_NUMPAD4,
		'26Numpad 5'  => Wx::WXK_NUMPAD5,
		'27Numpad 6'  => Wx::WXK_NUMPAD6,
		'28Numpad 7'  => Wx::WXK_NUMPAD7,
		'29Numpad 8'  => Wx::WXK_NUMPAD8,
		'30Numpad 9'  => Wx::WXK_NUMPAD9,
		'31Numpad *'  => Wx::WXK_MULTIPLY,
		'32Numpad +'  => Wx::WXK_ADD,
		'33Numpad -'  => Wx::WXK_SUBTRACT,
		'34Numpad .'  => Wx::WXK_DECIMAL,
		'35Numpad /'  => Wx::WXK_DIVIDE,
		'36F1'        => Wx::WXK_F1,
		'37F2'        => Wx::WXK_F2,
		'38F3'        => Wx::WXK_F3,
		'39F4'        => Wx::WXK_F4,
		'40F5'        => Wx::WXK_F5,
		'41F6'        => Wx::WXK_F6,
		'42F7'        => Wx::WXK_F7,
		'43F8'        => Wx::WXK_F8,
		'44F9'        => Wx::WXK_F9,
		'45F10'       => Wx::WXK_F10,
		'46F11'       => Wx::WXK_F11,
		'47F12'       => Wx::WXK_F12,
	);

	# Add alphanumerics
	for my $alphanum ( 'A' .. 'Z', '0' .. '9' ) {
		$keymap{ '20' . $alphanum } = ord($alphanum);
	}

	# Add symbols
	for my $symbol ( '~', '-', '=', '[', ']', ';', '\'', ',', '.', '/' ) {
		$keymap{ '50' . $symbol } = ord($symbol);
	}

	my @keys = sort keys %keymap;
	for my $key (@keys) {
		$key =~ s/^\d{2}//;
	}

	# Store it for later usage
	$self->{keys} = \@keys;

	$self->{key} = Wx::Choice->new(
		$self, -1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		\@keys,
	);
	$self->{key}->SetSelection(0);

	# Set key binding button
	$self->{button_set} = Wx::Button->new(
		$self, -1, Wx::gettext("&Set"),
	);
	$self->{button_set}->Enable(0);

	# Reset to default key binding button
	$self->{button_reset} = Wx::Button->new(
		$self, -1, Wx::gettext("&Reset"),
	);
	$self->{button_reset}->Enable(0);

	# Save button
	$self->{button_save} = Wx::Button->new(
		$self, Wx::wxID_OK, Wx::gettext("S&ave"),
	);
	$self->{button_save}->SetDefault;

	# Cancel button
	$self->{button_cancel} = Wx::Button->new(
		$self, Wx::wxID_CANCEL, Wx::gettext("&Cancel"),
	);

	#
	#----- Dialog Layout -------
	#

	# Filter sizer
	my $filter_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$filter_sizer->Add( $filter_label,   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$filter_sizer->Add( $self->{filter}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# CTRL/ALT Modifier sizer
	my $modifier_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$modifier_sizer->Add( $self->{ctrl}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$modifier_sizer->AddSpacer(3);
	$modifier_sizer->Add( $self->{alt}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Value setter sizer
	my $value_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$value_sizer->Add( $shortcut_label,, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->AddStretchSpacer;
	$value_sizer->Add( $modifier_sizer, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->AddSpacer(5);
	$value_sizer->Add( $plus_label_1, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->AddSpacer(5);
	$value_sizer->Add( $self->{shift}, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->AddSpacer(5);
	$value_sizer->Add( $plus_label_2, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->AddSpacer(5);
	$value_sizer->Add( $self->{key}, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->AddStretchSpacer;
	$value_sizer->Add( $self->{button_set},   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->Add( $self->{button_reset}, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Button sizer
	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $self->{button_save},   1, 0,          0 );
	$button_sizer->Add( $self->{button_cancel}, 1, Wx::wxLEFT, 5 );
	$button_sizer->AddSpacer(5);

	# Main vertical sizer
	my $vsizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$vsizer->Add( $filter_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->Add( $self->{list}, 1, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->Add( $value_sizer,  0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->AddSpacer(5);
	$vsizer->Add( $button_sizer, 0, Wx::wxALIGN_RIGHT, 5 );
	$vsizer->AddSpacer(5);

	# Hide value and info sizer at startup
	$vsizer->Show( 2, 0 );
	$vsizer->Show( 3, 0 );

	# Store vertical sizer reference for later usage
	$self->{vsizer} = $vsizer;

	# Wrap with a horizontal sizer to get left/right padding
	$sizer->Add( $vsizer, 1, Wx::wxALL | Wx::wxEXPAND, 5 );

	return;
}

# A Private method to binds events to controls
sub _bind_events {
	my $self = shift;

	# Set focus when Keypad Down or page down keys are pressed
	Wx::Event::EVT_CHAR(
		$self->{filter},
		sub {
			$self->_on_char( $_[1] );
		}
	);

	# Update filter search results on each text change
	Wx::Event::EVT_TEXT(
		$self,
		$self->{filter},
		sub {
			shift->_update_list;
		}
	);

	# When an item is selected, its values must be populated below
	Wx::Event::EVT_LIST_ITEM_SELECTED(
		$self,
		$self->{list},
		sub {
			shift->_on_list_item_selected(@_);
		}
	);

	# Set button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_set},
		sub {
			shift->_on_set_button;
		}
	);

	# Reset button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_reset},
		sub {
			shift->_on_reset_button;
		}
	);

	# Save button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_save},
		sub {
			shift->_on_save_button;
		}
	);

	# Cancel button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			shift->EndModal(Wx::wxID_CANCEL);
		}
	);

	return;
}

# Private method to handle on character pressed event
sub _on_char {
	my $self  = shift;
	my $event = shift;
	my $code  = $event->GetKeyCode;

	$self->{list}->SetFocus
		if ( $code == Wx::WXK_DOWN )
		or ( $code == Wx::WXK_NUMPAD_PAGEDOWN )
		or ( $code == Wx::WXK_PAGEDOWN );

	$event->Skip(1);

	return;
}

# Private method to handle the selection of a key binding item
sub _on_list_item_selected {
	my $self  = shift;
	my $event = shift;
	my $list  = $self->{list};

	# Fetch action name
	my $name = $list->GetItem( $list->GetFirstSelected, 2 )->GetText;
	my $binding = $self->{bindings}->{$name};

	# And get it shortcut
	my $shortcut = lc( $binding->{shortcut} );

	# Get the regular (i.e. non-modifier) key in the shortcut
	my @parts = split /-/, $shortcut;
	my $regular = @parts ? $parts[-1] : '';

	# Find the regular key index in the choice box
	my $regular_index = 0;
	my @keys          = @{ $self->{keys} };
	my $index         = 0;
	foreach my $key (@keys) {
		if ( $regular eq lc($key) ) {
			$regular_index = $index;
			last;
		}
		$index++;
	}

	# and update the UI
	$self->{key}->SetSelection($regular_index);
	$self->{ctrl}->SetValue( $shortcut =~ /ctrl/ ? 1 : 0 );
	$self->{alt}->SetValue( $shortcut  =~ /alt/  ? 1 : 0 );
	$self->{shift}->SetValue( ( $shortcut =~ /shift/ ) ? 1 : 0 );

	# Make sure the value and info sizer are not hidden
	$self->{vsizer}->Show( 2, 1 );
	$self->{vsizer}->Show( 3, 1 );
	$self->{vsizer}->Layout;

	return;
}

# Private method to update the UI from the provided key binding
sub _update_ui {
	my ( $self, $pref ) = @_;

	my $list  = $self->{list};
	my $index = $list->GetFirstSelected;

	return;
}

# Private method to handle the pressing of the set value button
sub _on_set_button {
	my $self = shift;

	# Prepare the key binding
	my $list  = $self->{list};
	my $index = $list->GetFirstSelected;
	my $name  = $list->GetItemText($index);

	return;
}

# Private method to handle the pressing of the reset to default button
sub _on_reset_button {
	my $self = shift;

	# Prepare the key binding
	my $list  = $self->{list};
	my $index = $list->GetFirstSelected;
	my $name  = $list->GetItemText($index);

	return;
}

# Private method to handle the save action
sub _on_save_button {
	my $self = shift;

	#TODO Implement saving of *Changed* key bindings

	# Bye bye dialog
	$self->EndModal(Wx::wxID_OK);

	return;
}

# Private method to update the key bindings list
sub _update_list {
	my $self   = shift;
	my $filter = quotemeta $self->{filter}->GetValue;

	# Clear list
	my $list = $self->{list};
	$list->DeleteAllItems;

	my $index               = -1;
	my $bindings            = $self->{bindings};
	my $alternateColor      = Wx::Colour->new( 0xED, 0xF5, 0xFF );
	my @sorted_binding_keys = sort { $bindings->{$a}->{label} cmp $bindings->{$b}->{label} } keys %$bindings;
	foreach my $name (@sorted_binding_keys) {

		# Fetch key binding and label
		my $binding = $bindings->{$name};
		my $label   = $binding->{label};

		# Ignore the key binding if it does not match the filter
		next if $label !~ /$filter/i;

		# Add the key binding to the list control
		$list->InsertStringItem( ++$index, $binding->{label} );
		$list->SetItem( $index, 1, $binding->{shortcut} );
		$list->SetItem( $index, 2, $name );

		# Alternating table colors
		$list->SetItemBackgroundColour( $index, $alternateColor ) unless $index % 2;
	}

	return;
}

# Private method to set item to bold
# Somehow SetItemFont is not there... hence i had to write this long workaround
sub _set_item_bold_font {
	my ( $self, $index, $bold ) = @_;

	my $list = $self->{list};
	my $item = $list->GetItem($index);
	my $font = $item->GetFont;
	$font->SetWeight( $bold ? Wx::wxFONTWEIGHT_BOLD : Wx::wxFONTWEIGHT_NORMAL );
	$item->SetFont($font);
	$list->SetItem($item);

	return;
}

# Private method to initialize a key bindings hash from Padre actions
sub _init_key_bindings {
	my $self = shift;


	my $bindings = ();
	my %actions  = %{ Padre::ide->actions };
	foreach my $name ( keys %actions ) {
		my $action = $actions{$name};
		my $shortcut = $action->shortcut ? $action->shortcut : '';
		$bindings->{$name} = {
			label    => $action->label_text,
			shortcut => $shortcut,
		};
	}
	$self->{bindings} = $bindings;

	return;
}

# Private method to resize list columns
sub _resize_columns {
	my $self = shift;

	# Resize all columns but the last to their biggest item width
	my $list = $self->{list};
	for ( 0 .. $list->GetColumnCount - 1 ) {
		$list->SetColumnWidth( $_, Wx::wxLIST_AUTOSIZE );
	}

	return;
}

=pod

=head2 C<show>

  $advanced->show($main);

Shows the dialog. Returns C<undef>.

=cut

sub show {
	my $self = shift;

	# Initialize Key Bindings
	$self->_init_key_bindings;

	# Set focus on the filter text field
	$self->{filter}->SetFocus;

	# Update the preferences list
	$self->_update_list;

	# resize columns
	$self->_resize_columns;

	# If it is not shown, show the dialog
	$self->ShowModal;

	return;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

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
