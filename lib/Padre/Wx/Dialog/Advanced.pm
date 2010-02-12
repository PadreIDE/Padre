package Padre::Wx::Dialog::Advanced;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();

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

	# Filtered list contains preferences
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

	# Value label
	my $value_label = Wx::StaticText->new( $self, -1, '&Value:' );

	# Value text field
	$self->{value} = Wx::TextCtrl->new( $self, -1, '' );

	# Set value button
	$self->{button_set} = Wx::Button->new(
		$self, -1, Wx::gettext("&Set"),
	);

	# Reset to default value button
	$self->{button_reset} = Wx::Button->new(
		$self, -1, Wx::gettext("&Reset"),
	);

	# OK button (obviously)
	$self->{button_ok} = Wx::Button->new(
		$self, Wx::wxID_OK, Wx::gettext("&OK"),
	);
	$self->{button_ok}->SetDefault;
	$self->{button_ok}->Enable(0);

	# Cancel button (obviously)
	$self->{button_cancel} = Wx::Button->new(
		$self, Wx::wxID_CANCEL, Wx::gettext("&Cancel"),
	);

	#----- Dialog Layout

	# Main button sizer
	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $self->{button_ok},     1, 0,          0 );
	$button_sizer->Add( $self->{button_cancel}, 1, Wx::wxLEFT, 5 );
	$button_sizer->AddSpacer(5);

	my $filter_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$filter_sizer->Add( $filter_label,   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$filter_sizer->Add( $self->{filter}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	my $bottom_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$bottom_sizer->Add( $value_label,   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$bottom_sizer->Add( $self->{value}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$bottom_sizer->Add( $self->{button_set},   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$bottom_sizer->Add( $self->{button_reset}, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );

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
			my ($this, $event)  = @_;
			my $code  = $event->GetKeyCode;

			$self->{list}->SetFocus
				if ($code == Wx::WXK_DOWN) or 
			           ($code == Wx::WXK_NUMPAD_PAGEDOWN) or
			           ($code == Wx::WXK_PAGEDOWN);

			$event->Skip(1);
		}
	);

	# Update filter search results on each text change
	Wx::Event::EVT_TEXT(
		$self,
		$self->{filter},
		sub {
			$_[0]->_update_list;
			return;
		}
	);

	# When an item is selected, its values must be populated below
	Wx::Event::EVT_LIST_ITEM_SELECTED(
		$self,
		$self->{list},
		sub {
		},
	);

	# Ok button
	Wx::Event::EVT_BUTTON( $self, $self->{button_ok},     sub { $_[0]->_on_ok_button; } );
	
	# Cancel button
	Wx::Event::EVT_BUTTON( $self, $self->{button_cancel}, sub { $_[0]->Hide; } );
}

#
# Private method to handle the pressing of the OK button
#
sub _on_ok_button {
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

	my $filter = $self->{filter}->GetValue();

	#quote the search string for safety
	$filter = quotemeta $filter;

	my %types = (
		Padre::Constant::BOOLEAN => Wx::gettext("Boolean"),
		Padre::Constant::POSINT  => Wx::gettext("Positive integer"),
		Padre::Constant::INTEGER => Wx::gettext("Integer"),
		Padre::Constant::ASCII   => Wx::gettext("ASCII"),
		Padre::Constant::PATH    => Wx::gettext("Path"),
	);

	my %settings = %Padre::Config::SETTING;
	my $list     = $self->{list};
	$list->DeleteAllItems;
	my $index = -1;
	for my $config_name ( keys %settings ) {

		# Ignore setting if it does not match the filter
		next if $config_name !~ /$filter/i;

		# Add the setting to the list control
		my $setting = $settings{$config_name};

		my $type      = $setting->type;
		my $type_name = $types{$type};
		unless ($type_name) {
			warn "Unknown type: $type while reading $config_name\n";
			next;
		}

		my $value = $config->$config_name;
		$list->InsertStringItem( ++$index, $config_name );
		$list->SetItem( $index, 1, "default" );
		$list->SetItem( $index, 2, $type_name );
		$list->SetItem( $index, 3, $value );
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
