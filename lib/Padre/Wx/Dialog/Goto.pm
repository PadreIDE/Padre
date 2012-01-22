package Padre::Wx::Dialog::Goto;

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};

=pod

=head1 NAME

Padre::Wx::Dialog::Goto - a dialog to jump to a user-specified line/position

=head1 PUBLIC API

=head2 C<new>

  my $goto = Padre::Wx::Dialog::Goto->new($main);

Returns a new C<Padre::Wx::Dialog::Goto> instance

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Go to'),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::RESIZE_BORDER | Wx::SYSTEM_MENU | Wx::CAPTION | Wx::CLOSE_BOX
	);

	# Minimum dialog size
	$self->SetMinSize( [ 330, 180 ] );

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);

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


	# a label to display current line/position
	$self->{current} = Wx::StaticText->new( $self, -1, '' );

	# Goto line label
	$self->{goto_label} = Wx::StaticText->new( $self, -1, '' );

	# Text field for the line number/position
	$self->{goto_text} = Wx::TextCtrl->new( $self, -1, '' );

	# Status label
	$self->{status_line} = Wx::StaticText->new( $self, -1, '' );

	# Line or position choice
	$self->{line_mode} = Wx::RadioBox->new(
		$self,               -1, Wx::gettext('Position type'),
		Wx::DefaultPosition, Wx::DefaultSize,
		[ _ln(), _cp() ]
	);

	# OK button (obviously)
	$self->{button_ok} = Wx::Button->new(
		$self, Wx::ID_OK, Wx::gettext('&OK'),
	);
	$self->{button_ok}->SetDefault;
	$self->{button_ok}->Enable(0);

	# Cancel button (obviously)
	$self->{button_cancel} = Wx::Button->new(
		$self, Wx::ID_CANCEL, Wx::gettext('&Cancel'),
	);

	#----- Dialog Layout

	# Main button sizer
	my $button_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$button_sizer->Add( $self->{button_ok},     1, 0,        0 );
	$button_sizer->Add( $self->{button_cancel}, 1, Wx::LEFT, 5 );
	$button_sizer->AddSpacer(5);

	# Create the main vertical sizer
	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->Add( $self->{line_mode},   0, Wx::ALL | Wx::EXPAND, 3 );
	$vsizer->Add( $self->{current},     0, Wx::ALL | Wx::EXPAND, 3 );
	$vsizer->Add( $self->{goto_label},  0, Wx::ALL | Wx::EXPAND, 3 );
	$vsizer->Add( $self->{goto_text},   0, Wx::ALL | Wx::EXPAND, 3 );
	$vsizer->Add( $self->{status_line}, 0, Wx::ALL | Wx::EXPAND, 2 );
	$vsizer->AddSpacer(5);
	$vsizer->Add( $button_sizer, 0, Wx::ALIGN_RIGHT, 5 );
	$vsizer->AddSpacer(5);

	# Wrap with a horizontal sizer to get left/right padding
	$sizer->Add( $vsizer, 1, Wx::ALL | Wx::EXPAND, 5 );

	return;

}

#
# Binds control events
#
sub _bind_events {
	my $self = shift;

	Wx::Event::EVT_ACTIVATE(
		$self,
		sub {
			my $self = shift;
			$self->_update_from_editor;
			$self->_update_label;
			$self->_validate;
			return;
		}
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->{goto_text},
		sub {
			$_[0]->_validate;
			return;
		}
	);

	Wx::Event::EVT_RADIOBOX(
		$self,
		$self->{line_mode},
		sub {
			my $self = shift;
			$self->_update_label;
			$self->_validate;
			return;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			$_[0]->Hide;
			return;
		}
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_ok},
		sub {
			$_[0]->_on_ok_button;
			return;
		},
	);

}

#
# Private method to handle the pressing of the OK button
#
sub _on_ok_button {
	my $self = shift;

	# Fetch values
	my $line_mode = $self->{line_mode}->GetStringSelection eq _ln();
	my $value = $self->{goto_text}->GetValue;

	# Destroy the dialog
	$self->Hide;

	if ( $value !~ m{^\d+$} ) {
		Padre::Current::_CURRENT->main->error( Wx::gettext('Not a positive number.') );
		return;
	}

	my $editor = $self->current->editor;

	# Bounds checking
	my $max_value = $line_mode ? $self->{max_line_number} : $self->{max_position};
	$value = $max_value if $value > $max_value;
	$value--;

	require Padre::Wx::Dialog::Positions;
	Padre::Wx::Dialog::Positions->set_position;

	# And then goto to the line or position
	# keeping it in the center of the editor
	# if possible
	if ($line_mode) {
		$editor->goto_line_centerize($value);
	} else {
		$editor->goto_pos_centerize($value);
	}

	return;
}

#
# Private method to update the goto line/position label
#
sub _update_label {
	my $self      = shift;
	my $line_mode = $self->{line_mode}->GetStringSelection;
	if ( $line_mode eq _ln() ) {
		$self->{goto_label}
			->SetLabel( sprintf( Wx::gettext('&Enter a line number between 1 and %s:'), $self->{max_line_number} ) );
		$self->{current}->SetLabel( sprintf( Wx::gettext('Current line number: %s'), $self->{current_line_number} ) );
	} elsif ( $line_mode eq _cp() ) {
		$self->{goto_label}
			->SetLabel( sprintf( Wx::gettext('&Enter a position between 1 and %s:'), $self->{max_position} ) );
		$self->{current}->SetLabel( sprintf( Wx::gettext('Current position: %s'), $self->{current_position} ) );
	} else {
		warn "Invalid choice value '$line_mode'\n";
	}
}

#
# Private method to validate user input
#
sub _validate {
	my $self = shift;

	my $line_mode = $self->{line_mode}->GetStringSelection eq _ln();
	my $value = $self->{goto_text}->GetValue;

	# If it is empty, do not warn about it but disable it though
	if ( $value eq '' ) {
		$self->{status_line}->SetLabel('');
		$self->{button_ok}->Enable(0);
		return;
	}

	# Should be an integer number
	if ( $value !~ /^\d+$/ ) {
		$self->{status_line}->SetLabel( Wx::gettext('Not a positive number.') );
		$self->{button_ok}->Enable(0);
		return;
	}

	# Bounds checking
	my $editor = $self->current->editor;
	my $max_value = $line_mode ? $self->{max_line_number} : $self->{max_position};
	if ( $value == 0 or $value > $max_value ) {
		$self->{status_line}->SetLabel( Wx::gettext('Out of range.') );
		$self->{button_ok}->Enable(0);

		return;
	}

	# Not problem, enable everything and clear errors
	$self->{button_ok}->Enable(1);
	$self->{status_line}->SetLabel('');
}

#
# Private method to update statistics from the current editor
#
sub _update_from_editor {
	my $self = shift;

	# Get the current editor
	my $editor = $self->current->editor;
	unless ($editor) {
		$self->Hide;
		return 0;
	}

	# Update max line number and position fields
	$self->{max_line_number}     = $editor->GetLineCount;
	$self->{max_position}        = $editor->GetLength + 1;
	$self->{current_line_number} = $editor->GetCurrentLine + 1;
	$self->{current_position}    = $editor->GetCurrentPos + 1;

	return 1;
}


=pod

=head2 C<show>

  $goto->show($main);

Show the dialog that the user can use to go to to a line number or character
position. Returns C<undef>.

=cut

sub show {
	my $self = shift;

	# Update current, and max bounds from the current editor
	return unless $self->_update_from_editor;

	# Update Goto labels
	$self->_update_label;

	# Select all of the line number/position so the user can overwrite
	# it quickly if he wants it
	$self->{goto_text}->SetSelection( -1, -1 );

	unless ( $self->IsShown ) {

		# If it is not shown, show the dialog
		$self->Show;
	}

	# Win32 tip: Always focus on wxwidgets controls only after
	# showing the dialog, otherwise you will lose the focus
	$self->{goto_text}->SetFocus;

	return;
}
sub _ln { Wx::gettext('Line number') }
sub _cp { Wx::gettext('Character position') }

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
