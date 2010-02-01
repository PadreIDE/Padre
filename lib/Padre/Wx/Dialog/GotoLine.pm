package Padre::Wx::Dialog::GotoLine;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();

our $VERSION = '0.55';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};

=pod

=head1 NAME

Padre::Wx::Dialog::GotoLine - a dialog to jump to a user-specifed line/position

=head1 PUBLIC API

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Go to line number/position'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION | Wx::wxCLOSE_BOX | Wx::wxSYSTEM_MENU
	);

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	# Create the controls
	$self->_create_controls($sizer);

	# Bind the control events
	$self->_bind_events;

	# wrap everything in a vbox to add some padding
	$self->SetSizerAndFit($sizer);
	$self->CentreOnParent;

	return $self;
}

#
# Create dialog controls
#
sub _create_controls {
	my ( $self, $sizer ) = @_;


	# Line or position checkbox
	$self->{line_or_position_checkbox} = Wx::CheckBox->new(
		$self, -1, Wx::gettext('Is it a line number or a position?'),
	);
	$self->{line_or_position_checkbox}->SetValue(1);

	# Goto line label
	$self->{gotoline_label} = Wx::StaticText->new(
		$self, -1, '', Wx::wxDefaultPosition, [ 250, -1 ],
	);

	# Input text control for the line number/position
	$self->{gotoline_text} = Wx::TextCtrl->new(
		$self, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
	);
	$self->{gotoline_text}->MoveBeforeInTabOrder( $self->{line_or_position_checkbox} );

	unless (Padre::Constant::WIN32) {

		#non-win32: Have the text field grab the focus so we can just start typing.
		$self->{gotoline_text}->SetFocus();
	}

	$self->{status_line} = Wx::StaticText->new(
		$self, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
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

	# Create the main vertical sizer
	my $vsizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$vsizer->Add( $self->{line_or_position_checkbox}, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->Add( $self->{gotoline_label},            0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->Add( $self->{gotoline_text},             0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->Add( $self->{status_line},               0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$vsizer->AddSpacer(5);
	$vsizer->Add( $button_sizer, 0, Wx::wxALIGN_RIGHT, 5 );
	$vsizer->AddSpacer(5);

	# Wrap with a horizontal sizer to get left/right padding
	$sizer->Add( $vsizer, 0, Wx::wxALL | Wx::wxEXPAND, 5 );

	return;

}

#
# Binds control events
#
sub _bind_events {
	my $self = shift;
	Wx::Event::EVT_TEXT(
		$self,
		$self->{gotoline_text},
		sub {
			$self->_validate;
			return;
		}
	);

	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{line_or_position_checkbox},
		sub {
			my $line_mode = $self->{line_or_position_checkbox}->IsChecked;
			$self->{gotoline_label}->SetLabel(
				$line_mode
				? sprintf( Wx::gettext("&Enter a line number between 1 and %s:"), $self->{max_line_number} )
				: sprintf( Wx::gettext("&Enter a position between 1 and %s:"),    $self->{max_position} )
			);
			$self->_validate;
			return;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			$_[0]->Destroy;
		}
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_ok},
		sub {
			my $self = shift;

			my $line_mode = $self->{line_or_position_checkbox}->IsChecked;

			my $value  = $self->{gotoline_text}->GetValue;
			my $editor = $self->current->editor;

			# Bounds checking
			my $max_value = $line_mode ? $self->{max_line_number} : $self->{max_position};
			$value = $max_value if $value > $max_value;
			$value--;

			$self->Destroy;
			if ($line_mode) {
				$editor->goto_line_centerize($value);
			} else {
				$editor->goto_pos_centerize($value);
			}
		},
	);

}

#
# Internal method to validate user input
#
sub _validate {
	my $self = shift;

	my $line_mode = $self->{line_or_position_checkbox}->IsChecked;
	my $value     = $self->{gotoline_text}->GetValue;

	# If it is empty, do not warn about it but disable it though
	if ( $value eq '' ) {
		$self->{status_line}->SetLabel('');
		$self->{button_ok}->Enable(0);
		return;
	}

	# Should be an integer number
	if ( $value !~ /^\d+$/ ) {
		$self->{status_line}->SetLabel( Wx::gettext('Not a positive number!') );
		$self->{button_ok}->Enable(0);
		return;
	}

	# Bounds checking
	my $editor = $self->current->editor;
	my $max_value = $line_mode ? $self->{max_line_number} : $self->{max_position};
	if ( $value == 0 or $value > $max_value ) {
		$self->{status_line}->SetLabel( Wx::gettext('Out of range!') );
		$self->{button_ok}->Enable(0);

		return;
	}

	# Not problem, enable everything and clear errors
	$self->{button_ok}->Enable(1);
	$self->{status_line}->SetLabel('');
}

=pod

=head2 C<modal>

  Padre::Wx::Dialog::GotoLine->modal($main);

Single-shot modal dialog call to set the line number from the user.
Returns C<undef>.

=cut

sub modal {
	my $class = shift;
	my $self  = $class->new(@_);

	# Update Goto line number label
	my $editor = $self->current->editor;
	unless ($editor) {
		$self->Destroy;
		return;
	}
	$self->{max_line_number} = $editor->GetLineCount;
	$self->{max_position}    = $editor->GetLength + 1;
	$self->{gotoline_label}
		->SetLabel( sprintf( Wx::gettext("Enter a line number between 1 and %s:"), $self->{max_line_number} ) );

	# Go modal!
	my $ok = $self->ShowModal;

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
