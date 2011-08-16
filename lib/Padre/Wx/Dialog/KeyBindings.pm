package Padre::Wx::Dialog::KeyBindings;

use 5.008;
use strict;
use warnings;
use Padre::Constant         ();
use Padre::Config           ();
use Padre::Util             ('_T');
use Padre::Wx               ();
use Padre::Wx::Role::Main   ();
use Padre::Wx::Role::Dialog ();

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Padre::Wx::Role::Dialog
	Wx::Dialog
};

# Creates the key bindings dialog and returns the instance
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

	# Set some internal parameters
	$self->{sortcolumn}  = 0;
	$self->{sortreverse} = 0;

	# Minimum dialog size
	$self->SetMinSize( [ 770, 550 ] );

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
	my @titles = qw(Action Description Shortcut);
	foreach my $i ( 0 .. 2 ) {
		$self->{list}->InsertColumn( $i, Wx::gettext( $titles[$i] ) );
		$self->{list}->SetColumnWidth( $i, Wx::wxLIST_AUTOSIZE );
	}

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
	my @keys = (
		_T('None'),   _T('Backspace'), _T('Tab'),    _T('Space'),  _T('Up'),   _T('Down'),
		_T('Left'),   _T('Right'),     _T('Insert'), _T('Delete'), _T('Home'), _T('End'),
		_T('PageUp'), _T('PageDown'),  _T('Enter'),  _T('Escape'),
		'F1',       'F2',       'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
		'A' .. 'Z', '0' .. '9', '~',  '-',  '=',  '[',  ']',  ';',  '\'', ',',   '.',   '/'
	);
	$self->{keys} = \@keys;

	my @translated_keys = map { Wx::gettext($_) } @keys;
	$self->{key} = Wx::Choice->new(
		$self, -1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		\@translated_keys,
	);
	$self->{key}->SetSelection(0);

	# TODO tooltips for all buttons

	# Set key binding button
	$self->{button_set} = Wx::Button->new(
		$self, -1, Wx::gettext('&Set'),
	);
	$self->{button_set}->Enable(1);

	# Delete button
	$self->{button_delete} = Wx::Button->new(
		$self, -1, Wx::gettext('&Delete'),
	);
	$self->{button_delete}->Enable(1);

	# Reset button
	$self->{button_reset} = Wx::Button->new(
		$self, -1, Wx::gettext('&Reset'),
	);
	$self->{button_reset}->SetToolTip( Wx::gettext('Reset to default shortcut') );
	$self->{button_reset}->Enable(1);

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
	$value_sizer->Add( $shortcut_label, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
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
	$value_sizer->Add( $self->{button_set},    0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->Add( $self->{button_delete}, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$value_sizer->Add( $self->{button_reset},  0, Wx::wxALIGN_CENTER_VERTICAL, 5 );

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

	# When the title is clicked, sort the items
	Wx::Event::EVT_LIST_COL_CLICK(
		$self,
		$self->{list},
		sub {
			shift->list_col_click(@_);
		},
	);

	# Set button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_set},
		sub {
			shift->_on_set_button;
		}
	);

	# Delete button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_delete},
		sub {
			shift->_on_delete_button;
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

# Translates the shortcut to its native language
sub _translate_shortcut {
	my ($shortcut) = @_;

	my @parts = split /-/, $shortcut;
	my $regular_key = @parts ? $parts[-1] : '';

	return join '-', map { Wx::gettext($_) } @parts;
}

# Private method to handle the selection of a key binding item
sub _on_list_item_selected {
	my $self  = shift;
	my $event = shift;

	my $list        = $self->{list};
	my $index       = $list->GetFirstSelected;
	my $action_name = $list->GetItemText($index);
	my $action      = $self->ide->actions->{$action_name};

	my $shortcut = $self->ide->actions->{$action_name}->shortcut;
	$shortcut = '' if not defined $shortcut;

	$self->{button_reset}->Enable( $shortcut ne $self->config->default( $action->shortcut_setting ) );

	$self->{button_delete}->Enable( $shortcut ne '' );

	$self->_update_shortcut_ui($shortcut);

	return;
}

# Updates the shortcut UI
sub _update_shortcut_ui {
	my ( $self, $shortcut ) = @_;

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
	$self->{ctrl}->SetValue( $shortcut  =~ /Ctrl/  ? 1 : 0 );
	$self->{alt}->SetValue( $shortcut   =~ /Alt/   ? 1 : 0 );
	$self->{shift}->SetValue( $shortcut =~ /Shift/ ? 1 : 0 );

	# Make sure the value and info sizer are not hidden
	$self->{vsizer}->Show( 2, 1 );
	$self->{vsizer}->Show( 3, 1 );
	$self->{vsizer}->Layout;

	return;
}

# Private method to handle the pressing of the set value button
sub _on_set_button {
	my $self = shift;

	my $index       = $self->{list}->GetFirstSelected;
	my $action_name = $self->{list}->GetItemText($index);

	my @key_list = ();
	for my $regular_key ( 'Shift', 'Ctrl', 'Alt' ) {
		push @key_list, $regular_key if $self->{ lc $regular_key }->GetValue;
	}
	my $key_index   = $self->{key}->GetSelection;
	my $regular_key = $self->{keys}->[$key_index];
	push @key_list, $regular_key if not $regular_key eq 'None';
	my $shortcut = join '-', @key_list;

	$self->_try_to_set_binding( $action_name, $shortcut );

	return;
}

# Tries to set the binding and asks the user if he want to set the shortcut if has already be used elsewhere
sub _try_to_set_binding {
	my ( $self, $action_name, $shortcut ) = @_;

	my $other_action = $self->ide->shortcuts->{$shortcut};
	if ( defined $other_action && $other_action->name ne $action_name ) {
		my $answer = $self->yes_no(
			sprintf(
				Wx::gettext("The shortcut '%s' is already used by the action '%s'.\n"),
				$shortcut, $other_action->label_text
				)
				. Wx::gettext('Do you want to override it with the selected action?'),
			Wx::gettext('Override Shortcut')
		);
		if ($answer) {
			$self->_set_binding( $other_action->name, '' );
		} else {
			return;
		}
	}

	$self->_set_binding( $action_name, $shortcut );

	return;
}

# Sets the key binding in Padre's configuration
sub _set_binding {
	my ( $self, $action_name, $shortcut ) = @_;

	my $shortcuts = $self->ide->shortcuts;
	my $action    = $self->ide->actions->{$action_name};

	# modify shortcut registry
	my $old_shortcut = $action->shortcut;
	delete $shortcuts->{$old_shortcut} if defined $old_shortcut;
	$shortcuts->{$shortcut} = $action;

	# set the action's shortcut
	$action->shortcut( $shortcut eq '' ? undef : $shortcut );

	# modify the configuration database
	$self->config->set( $action->shortcut_setting, $shortcut );
	$self->config->write;

	# Update the action's UI
	my $non_default = $self->config->default( $action->shortcut_setting ) ne $shortcut;
	$self->_update_action_ui( $action_name, $shortcut, $non_default );

	return;
}

# Private method to update the UI from the provided preference
sub _update_action_ui {

	my ( $self, $action_name, $shortcut, $non_default ) = @_;

	my $list = $self->{list};
	my $index = $list->FindItem( -1, $action_name );

	$self->{button_reset}->Enable($non_default);
	$list->SetItem( $index, 2, _translate_shortcut($shortcut) );
	$self->_set_item_bold_font( $index, $non_default );

	$self->_update_shortcut_ui($shortcut);

	return;
}

# Private method to handle the pressing of the delete button
sub _on_delete_button {
	my $self = shift;

	# Prepare the key binding
	my $index       = $self->{list}->GetFirstSelected;
	my $action_name = $self->{list}->GetItemText($index);

	$self->_set_binding( $action_name, '' );

	return;
}

# Private method to handle the pressing of the reset button
sub _on_reset_button {
	my $self = shift;

	my $index       = $self->{list}->GetFirstSelected;
	my $action_name = $self->{list}->GetItemText($index);
	my $action      = $self->ide->actions->{$action_name};

	$self->_try_to_set_binding(
		$action_name,
		$self->config->default( $action->shortcut_setting )
	);

	return;
}

# Private method to handle the close action
sub _on_close_button {
	my $self = shift;
	my $main = $self->GetParent;

	# re-create menu to activate shortcuts
	delete $main->{menu};
	$main->{menu} = Padre::Wx::Menubar->new($main);
	$main->SetMenuBar( $main->menu->wx );
	$main->refresh;

	$self->EndModal(Wx::wxID_CLOSE);
	return;
}

# Private method to update the key bindings list view
sub _update_list {
	my $self   = shift;
	my $filter = quotemeta $self->{filter}->GetValue;

	# Clear list
	my $list = $self->{list};
	$list->DeleteAllItems;

	my $actions         = $self->ide->actions;
	my $real_color      = Wx::SystemSettings::GetColour(Wx::wxSYS_COLOUR_WINDOW);
	my $alternate_color = Wx::Colour->new(
		int( $real_color->Red * 0.9 ),
		int( $real_color->Green * 0.9 ),
		$real_color->Blue,
	);
	my $index = 0;

	my @action_names = sort { $a cmp $b } keys %$actions;
	if ( $self->{sortcolumn} == 1 ) {

		# Sort by Descreption
		@action_names = sort { $actions->{$a}->label_text cmp $actions->{$b}->label_text } keys %$actions;
	}
	if ( $self->{sortcolumn} == 2 ) {

		# Sort by Shortcut
		@action_names = sort {
			_translate_shortcut( $actions->{$a}->shortcut || '' )
				cmp _translate_shortcut( $actions->{$b}->shortcut || '' )
		} keys %$actions;
	}
	if ( $self->{sortreverse} ) {
		@action_names = reverse @action_names;
	}

	foreach my $action_name (@action_names) {
		my $action = $actions->{$action_name};
		my $shortcut = defined $action->shortcut ? $action->shortcut : '';

		# Ignore key binding if it does not match the filter
		next
			if $action->label_text !~ /$filter/i
				and $action_name !~ /$filter/i
				and $shortcut !~ /$filter/i;

		# Add the key binding to the list control
		$list->InsertStringItem( $index, $action_name );
		$list->SetItem( $index, 1, $action->label_text );
		$list->SetItem( $index, 2, _translate_shortcut($shortcut) );

		# Non-default (i.e. overriden) shortcuts should have a bold font
		my $non_default = $self->config->default( $action->shortcut_setting ) ne $shortcut;
		$self->_set_item_bold_font( $index, $non_default );

		# Alternating table colors
		$list->SetItemBackgroundColour( $index, $alternate_color ) unless $index % 2;
		$index++;
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

sub list_col_click {
	my $self     = shift;
	my $event    = shift;
	my $column   = $event->GetColumn;
	my $prevcol  = $self->{sortcolumn};
	my $reversed = $self->{sortreverse};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{sortcolumn}  = $column;
	$self->{sortreverse} = $reversed;
	$self->_update_list;
	return;
}

# Shows the key binding dialog
sub show {
	my $self = shift;

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

  my $key_bindings = Padre::Wx::Dialog::KeyBindings->new($main);

Returns a new C<Padre::Wx::Dialog::KeyBindings> instance

=head2 C<show>

  $key_bindings->show($main);

Shows the dialog. Returns C<undef>.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut




# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
