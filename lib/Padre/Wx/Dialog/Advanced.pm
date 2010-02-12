package Padre::Wx::Dialog::Advanced;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();
use Padre::Config              ();

our $VERSION = '0.56';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};

=pod

=head1 NAME

Padre::Wx::Dialog::Advanced - a dialog to show and configure advanced preferences

=head1 DESCRIPTION

The idea is to implement a Mozilla-style about:config for Padre. This will make
playing with experimental, advanced, and sekrit settings a breeze.

=head1 PUBLIC API

=head2 C<new>

  my $advanced = Padre::Wx::Dialog::Advanced->new($main);

Returns a new C<Padre::Wx::Dialog::Advanced> instance

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Advanced Settings'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Minimum dialog size
	$self->SetMinSize( [ 500, 550 ] );

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	# Create the controls
	$self->_create_controls($sizer);

	# Bind the control events
	$self->_bind_events;

	# wrap everything in a vbox to add some padding
	$self->SetSizer($sizer);
	$self->Fit;
	$self->CentreOnParent;

	return $self;
}

#
# Create dialog controls
#
sub _create_controls {
	my ( $self, $sizer ) = @_;


	# Filter label
	my $filter_label = Wx::StaticText->new( $self, -1, '&Filter:' );

	# Filter text field
	$self->{filter} = Wx::TextCtrl->new( $self, -1, '' );

	# Filtered preferences list
	$self->{list} = Wx::ListView->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL,
	);
	$self->{list}->InsertColumn( 0, Wx::gettext('Preference Name') );
	$self->{list}->InsertColumn( 1, Wx::gettext('Status') );
	$self->{list}->InsertColumn( 2, Wx::gettext('Type') );
	$self->{list}->InsertColumn( 3, Wx::gettext('Value') );

	# Preference value label
	my $value_label = Wx::StaticText->new( $self, -1, '&Value:' );

	# Preference value text field
	$self->{value} = Wx::TextCtrl->new( $self, -1, '' );

	# Set preference value button
	$self->{button_set} = Wx::Button->new(
		$self, -1, Wx::gettext("&Set"),
	);

	# Reset to default preference value button
	$self->{button_reset} = Wx::Button->new(
		$self, -1, Wx::gettext("&Reset"),
	);

	# Save button
	$self->{button_save} = Wx::Button->new(
		$self, Wx::wxID_OK, Wx::gettext("&Save"),
	);
	$self->{button_save}->SetDefault;
	$self->{button_save}->Enable(0);

	# Cancel button
	$self->{button_cancel} = Wx::Button->new(
		$self, Wx::wxID_CANCEL, Wx::gettext("&Cancel"),
	);

	#
	#----- Dialog Layout -------
	#

	# Top filter sizer
	my $filter_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$filter_sizer->Add( $filter_label,   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$filter_sizer->Add( $self->{filter}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Bottom preference value setter sizer
	my $bottom_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$bottom_sizer->Add( $value_label,          0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$bottom_sizer->Add( $self->{value},        1, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$bottom_sizer->Add( $self->{button_set},   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$bottom_sizer->Add( $self->{button_reset}, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Bottom button sizer
	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $self->{button_save},   1, 0,          0 );
	$button_sizer->Add( $self->{button_cancel}, 1, Wx::wxLEFT, 5 );
	$button_sizer->AddSpacer(5);

	# Create the main vertical sizer
	my $vsizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$vsizer->Add( $filter_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->Add( $self->{list}, 1, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->Add( $bottom_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->AddSpacer(5);
	$vsizer->Add( $button_sizer, 0, Wx::wxALIGN_RIGHT, 5 );
	$vsizer->AddSpacer(5);

	# Wrap with a horizontal sizer to get left/right padding
	$sizer->Add( $vsizer, 1, Wx::wxALL | Wx::wxEXPAND, 5 );

	return;
}

#
# A Private method to binds events to controls
#
sub _bind_events {
	my $self = shift;

	# Set focus when Keypad Down or page down keys are pressed
	Wx::Event::EVT_CHAR(
		$self->{filter},
		sub {
			$self->_on_char($_[1]);
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

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self,
		$self->{list},
		sub {
			shift->_on_list_item_activated(@_);
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
			shift->Hide; 
		}
	);
}

#
# Private method to handle on character pressed event
#
sub _on_char {
	my $self = shift;
	my $event = shift;
	my $code = $event->GetKeyCode;

	$self->{list}->SetFocus
		if ( $code == Wx::WXK_DOWN )
		or ( $code == Wx::WXK_NUMPAD_PAGEDOWN )
		or ( $code == Wx::WXK_PAGEDOWN );

	$event->Skip(1);

	return;
}

#
# Private method to handle the selection of a preference item
#
sub _on_list_item_selected {
	my $self  = shift;
	my $event = shift;

	my $setting_name = $event->GetLabel;
	my $config       = $self->main->config;

	$self->{value}->SetValue( $config->$setting_name );
	$self->{button_reset}->Enable( not $self->{preferences}{$setting_name}->{is_default} );

	return;
}

sub _on_list_item_activated {
	my $self  = shift;
	my $event = shift;

	my $setting_name = $event->GetLabel;
	my $config       = $self->main->config;

	#print "value: " . $config->$setting_name . "\n";
	#	my $value = ($config->$setting_name) ? 0 : 1;
	#	$self->{value}->SetValue( $value );
	#	$config->$setting_name( $value );

	return;
}


#
# Private method to handle the pressing of the set value button
#
sub _on_set_button {
	my $self = shift;

	#TODO implement set button action

	return;
}

#
# Private method to handle the pressing of the reset to default button
#
sub _on_reset_button {
	my $self = shift;

	#TODO implement reset button action

	return;
}

#
# Private method to handle the pressing of the save button
#
sub _on_save_button {
	my $self = shift;

	# Destroy the dialog
	$self->Hide;

	return;
}


#
# Private method to update the preferences list
#
sub _update_list {
	my $self = shift;

	my $config = $self->main->config;

	my $filter = $self->{filter}->GetValue;

	#quote the search string for safety
	$filter = quotemeta $filter;

	my $list = $self->{list};
	$list->DeleteAllItems;
	my $index       = -1;
	my $preferences = $self->{preferences};
	my $alternateColor = Wx::Colour->new(0xED,0xF5,0xFF);
	for my $name ( sort keys %$preferences ) {

		# Ignore setting if it does not match the filter
		next if $name !~ /$filter/i;

		# Add the setting to the list control
		my $setting = $preferences->{$name};
		my $is_default = $setting->{is_default};

		$list->InsertStringItem( ++$index, $name );
		$list->SetItem( $index, 1, $is_default ? Wx::gettext('Default') : Wx::gettext('User set') );
		$list->SetItem( $index, 2, $setting->{type_name} );
		$list->SetItem( $index, 3, $setting->{value} );

		# Alternating table colors
		unless($index % 2) {
			$list->SetItemBackgroundColour( $index, $alternateColor);
		}

		unless($is_default) {
			my $item = $list->GetItem( $index );
			my $font = $item->GetFont;
			$font->SetWeight(Wx::wxFONTWEIGHT_BOLD);
			$item->SetFont($font);
			$list->SetItemTextColour( $index, Wx::wxRED );
		}
	}

	return;
}

#
# Private method to initialize a preferences hash from the local configuration
#
sub _init_preferences {
	my $self = shift;

	my %settings = %Padre::Config::SETTING;
	my $config   = $self->main->config;
	my %types    = (
		Padre::Constant::BOOLEAN => Wx::gettext("Boolean"),
		Padre::Constant::POSINT  => Wx::gettext("Positive integer"),
		Padre::Constant::INTEGER => Wx::gettext("Integer"),
		Padre::Constant::ASCII   => Wx::gettext("ASCII"),
		Padre::Constant::PATH    => Wx::gettext("Path"),
	);

	$self->{preferences} = ();
	for my $name ( sort keys %settings ) {
		my $setting = $settings{$name};

		my $type = $setting->type;
		my $type_name = $types{$type};
		unless ($type_name) {
			warn "Unknown type: $type while reading $name\n";
			next;
		}

		my $value         = $config->$name;
		my $default_value = $setting->default;
		my $is_default = 
			($type == Padre::Constant::ASCII or $type == Padre::Constant::PATH) ?
			$value eq $default_value :
			$value == $default_value;

		$self->{preferences}{$name} = {
			'is_default' => $is_default,
			'default'    => $default_value,
			'type'       => $type,
			'type_name'  => $type_name,
			'value'      => $value,
		};
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

	# Initialize Preferences
	$self->_init_preferences;

	# Set focus on the filter text field
	$self->{filter}->SetFocus;

	# Update the preferences list
	$self->_update_list;

	# Resize columns to their biggest item width
	for ( 0 .. 3 ) {
		$self->{list}->SetColumnWidth( $_, Wx::wxLIST_AUTOSIZE );
	}

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
