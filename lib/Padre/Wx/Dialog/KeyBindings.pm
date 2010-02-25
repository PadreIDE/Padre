package Padre::Wx::Dialog::KeyBindings;

use 5.008;
use strict;
use warnings;
use Padre::Constant            ();
use Padre::Config              ();
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();

our $VERSION = '0.57';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};

# Padre config type to description hash
my %TYPES = (
	Padre::Constant::BOOLEAN => Wx::gettext('Boolean'),
	Padre::Constant::POSINT  => Wx::gettext('Positive Integer'),
	Padre::Constant::INTEGER => Wx::gettext('Integer'),
	Padre::Constant::ASCII   => Wx::gettext('String'),
	Padre::Constant::PATH    => Wx::gettext('File/Directory'),
);

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
		Wx::gettext('Key Bindings'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Minimum dialog size
	$self->SetMinSize( [ 450, 550 ] );

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
	my $filter_label = Wx::StaticText->new( $self, -1, '&Filter:' );

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

	# Preference value label
	my $value_label = Wx::StaticText->new( $self, -1, '&Value:' );

	# Preference value text field
	$self->{value} = Wx::TextCtrl->new( $self, -1, '' );
	$self->{value}->Enable(0);

	# Boolean value radio button fields
	$self->{true}  = Wx::RadioButton->new( $self, -1, Wx::gettext('True') );
	$self->{false} = Wx::RadioButton->new( $self, -1, Wx::gettext('False') );
	$self->{true}->Hide;
	$self->{false}->Hide;

	# System default
	my $default_label = Wx::StaticText->new( $self, -1, Wx::gettext('Default value:') );
	$self->{default_value} = Wx::TextCtrl->new(
		$self,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_READONLY
	);
	$self->{default_value}->Enable(0);

	# Set preference value button
	$self->{button_set} = Wx::Button->new(
		$self, -1, Wx::gettext("&Set"),
	);
	$self->{button_set}->Enable(0);

	# Reset to default key binding value button
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

	# Boolean sizer
	my $boolean_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$boolean_sizer->AddStretchSpacer;
	$boolean_sizer->Add( $self->{true},  1, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$boolean_sizer->Add( $self->{false}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$boolean_sizer->AddStretchSpacer;

	# Store boolean sizer reference for later usage
	$self->{boolean} = $boolean_sizer;

	# Value setter sizer
	my $value_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$value_sizer->Add( $value_label,          0, Wx::wxALIGN_CENTER_VERTICAL,                5 );
	$value_sizer->Add( $self->{value},        1, Wx::wxALIGN_CENTER_VERTICAL,                5 );
	$value_sizer->Add( $boolean_sizer,        1, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxEXPAND, 5 );
	$value_sizer->Add( $self->{button_set},   0, Wx::wxALIGN_CENTER_VERTICAL,                5 );
	$value_sizer->Add( $self->{button_reset}, 0, Wx::wxALIGN_CENTER_VERTICAL,                5 );

	# Default value and options sizer
	my $info_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$info_sizer->Add( $default_label,         0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$info_sizer->Add( $self->{default_value}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

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
	$vsizer->Add( $info_sizer,   0, Wx::wxALL | Wx::wxEXPAND, 3 );
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
	my $pref  = $self->{bindings}->{ $event->GetLabel };
	my $type  = $pref->{type};

	return;
}

# Private method to update the UI from the provided key binding
sub _update_ui {
	my ( $self, $pref ) = @_;

	my $list       = $self->{list};
	my $index      = $list->GetFirstSelected;

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

	my $list = $self->{list};
	$list->DeleteAllItems;

	my $index          = -1;
	my $bindings    = $self->{bindings};
	my $alternateColor = Wx::Colour->new( 0xED, 0xF5, 0xFF );
	foreach my $name ( sort keys %$bindings ) {

		# Ignore setting if it does not match the filter
		next if $name !~ /$filter/i;

		# Add the setting to the list control
		my $binding       = $bindings->{$name};

		$list->InsertStringItem( ++$index, $binding->{name} );
		$list->SetItem( $index, 1, $binding->{value} );

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
	my $self   = shift;


	my $bindings = ();
	my %actions      = %{ Padre::ide->actions };
	foreach my $name ( keys %actions ) {
		my $action = $actions{$name};
		$bindings->{$name} = {
			name  => $name,
			value => $action->label_text,
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
	for ( 0 .. 1 ) {
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
