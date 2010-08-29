package Padre::Wx::Dialog::KeyBindings;

use 5.008;
use strict;
use warnings;
use Padre::Constant       ();
use Padre::Config         ();
use Padre::Wx             ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.69';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};


sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Key Bindings'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Minimum dialog size
	$self->SetMinSize( [ 717, 550 ] );

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
	$self->{list}->InsertColumn( 0, Wx::gettext('Action') );
	$self->{list}->InsertColumn( 1, Wx::gettext('Description') );
	$self->{list}->InsertColumn( 2, Wx::gettext('Shortcut') );

	# TODO add tooltip with the comments

	# Shortcut label
	my $shortcut_label = Wx::StaticText->new( $self, -1, Wx::gettext('Sh&ortcut:') );

	# modifier radio button fields
	$self->{ctrl}  = Wx::CheckBox->new( $self, -1, Wx::gettext('Ctrl') );
	$self->{alt}   = Wx::CheckBox->new( $self, -1, Wx::gettext('Alt') );
	$self->{shift} = Wx::CheckBox->new( $self, -1, Wx::gettext('Shift') );

	# + labels
	my $plus_label_1 = Wx::StaticText->new( $self, -1, '+' );
	my $plus_label_2 = Wx::StaticText->new( $self, -1, '+' );

	# key choice list
	$self->{keys} = [
		qw(None Backspace Tab Space Up Down Left Right Insert Delete Home
			End PageUp PageDown Enter Escape F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
			), 'A' .. 'Z', '0' .. '9', '~', '-', '=', '[', ']', ';', '\'', ',', '.', '/'
	];

	$self->{key} = Wx::Choice->new(
		$self, -1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		$self->{keys}, # TODO translate
	);
	$self->{key}->SetSelection(0);

	# Set key binding button
	$self->{button_set} = Wx::Button->new(
		$self, -1, Wx::gettext('&Set'),
	);
	$self->{button_set}->Enable(1);

	# Reset to default key binding button
	$self->{button_reset} = Wx::Button->new(
		$self, -1, Wx::gettext('&Reset'),
	);
	$self->{button_reset}->Enable(0);

	# Close button
	$self->{button_close} = Wx::Button->new(
		$self, Wx::wxID_CANCEL, Wx::gettext('&Close'),
	);

	#
	#----- Dialog Layout -------
	#

	# Filter sizer
	my $filter_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$filter_sizer->Add( $filter_label,   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$filter_sizer->Add( $self->{filter}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Ctrl/Alt Modifier sizer
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
	$button_sizer->Add( $self->{button_close}, 1, Wx::wxLEFT, 5 );
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

	# Close button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_close},
		sub {
			shift->_on_close_button;
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

	my $list        = $self->{list};
	my $index       = $list->GetFirstSelected;
	my $action_name = $list->GetItemText($index);

	my $shortcut = Padre->ide->actions->{$action_name}->shortcut;
	$shortcut = '' if not defined $shortcut;

	# Get the regular (i.e. non-modifier) key in the shortcut
	my @parts = split /-/, $shortcut;
	my $regular_key = @parts ? $parts[-1] : '';

	# Find the regular key index in the choice box
	my $regular_index = 0;
	my @keys          = @{ $self->{keys} };
	for ( my $i = 0; $i < scalar @keys; $i++ ) {
		if ( $regular_key eq $keys[$i] ) {
			$regular_index = $i;
			last;
		}
	}

	# and update the UI
	$self->{key}->SetSelection($regular_index);
	$self->{ctrl}->SetValue( $shortcut =~ /Ctrl/ ? 1 : 0 );
	$self->{alt}->SetValue( $shortcut  =~ /Alt/  ? 1 : 0 );
	$self->{shift}->SetValue( ( $shortcut =~ /Shift/ ) ? 1 : 0 );

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

	my $list  = $self->{list};
	my $index = $list->GetFirstSelected;
	my $name  = $list->GetItemText($index);

	my @key_list = ();
	for my $regular_key ( 'Shift', 'Ctrl', 'Alt' ) {
		push @key_list, $regular_key if $self->{ lc $regular_key }->GetValue;
	}
	my $regular_key = $self->{keys}->[ $self->{key}->GetSelection ];
	push @key_list, $regular_key if not $regular_key eq 'None';
	my $shortcut = join '-', @key_list;

	return if $shortcut eq '';

	my $shortcuts = Padre->ide->{shortcuts};
	if ( exists $shortcuts->{$shortcut} ) {
		warn "Found a duplicate shortcut '$shortcut' with " . $shortcuts->{$shortcut}->name . " for '$name'\n";

		# TODO instead of a warning, offer to overwrite the old shortcut.
	} else {
		$shortcuts->{$shortcut} = Padre->ide->actions->{$name};
		$self->{bindings}->{$name}->{shortcut} = $shortcut;
		warn "Set shortcut '$shortcut' for action '$name'\n";

		Padre->ide->actions->{$name}->shortcut($shortcut);

		my $setting = "keyboard_shortcut_$name";
		$setting =~ s/\W/_/g; # setting names must be valid subroutine names
		$self->config->set( $setting, $shortcut );
		$self->config->write;

		$self->_update_list;
	}

	return;
}

# Private method to handle the pressing of the reset to default button
sub _on_reset_button {
	my $self = shift;

	# Prepare the key binding
	my $list  = $self->{list};
	my $index = $list->GetFirstSelected;
	my $name  = $list->GetItemText($index);

	my $action = Padre->ide->actions->{$name};

	## TODO
	# restore default or previous value?
	# ensure that list contains right value ...

	return;
}

# Private method to handle the close action
sub _on_close_button {
	my $self = shift;
	my $main = $self->GetParent;

	delete $main->{menu};
	$main->{menu} = Padre::Wx::Menubar->new($main);
	$main->SetMenuBar( $main->menu->wx );
	$main->refresh;

	$self->EndModal(Wx::wxID_CLOSE);
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
	my @sorted_binding_keys = sort { $a cmp $b } keys %$bindings;
	foreach my $name (@sorted_binding_keys) {

		# Fetch key binding and label
		my $binding = $bindings->{$name};
		my $label   = $binding->{label};

		# Ignore the key binding if it does not match the filter
		next if $label !~ /$filter/i;

		# Add the key binding to the list control
		$list->InsertStringItem( ++$index, $name );
		$list->SetItem( $index, 1, $binding->{label} );
		$list->SetItem( $index, 2, $binding->{shortcut} );

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

	my $bindings = {};
	my %actions  = %{ Padre::ide->actions };
	foreach my $name ( keys %actions ) {
		my $action = $actions{$name};
		my $shortcut = $action->shortcut ? $action->shortcut : '';
		warn "Duplicate action name: '" . $action->label_text . "'\n" if exists $bindings->{ $action->label_text };
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


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::KeyBindings - a dialog to show and configure key bindings

=head1 DESCRIPTION

This dialog lets the user search for an action and then configure a new
shortcut if needed

=head1 PUBLIC API

=head2 C<new>

  my $advanced = Padre::Wx::Dialog::KeyBindings->new($main);

Returns a new C<Padre::Wx::Dialog::KeyBindings> instance

=head2 C<show>

  $advanced->show($main);

Shows the dialog. Returns C<undef>.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
