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

Padre::Wx::Dialog::GotoLine - a dialog to goto a line number in the current editor

=head2 C<new>

  my $find = Padre::Wx::Dialog::GotoLine->new($main);

Create and return a C<Padre::Wx::Dialog::GotoLine> "Goto Line" dialog.

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Go to Line number'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION | Wx::wxCLOSE_BOX | Wx::wxSYSTEM_MENU
	);

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);

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

	#----- dialog controls

	# Goto line label
	$self->{gotoline_label} = Wx::StaticText->new(
		$self, -1, '', Wx::wxDefaultPosition, [ 250, -1 ],
	);

	# Input text control for the line number
	$self->{gotoline_text} = Wx::TextCtrl->new(
		$self, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
	);

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

	# Main button cluster
	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $self->{button_ok},     1, 0,          0 );
	$button_sizer->Add( $self->{button_cancel}, 1, Wx::wxLEFT, 5 );
	$button_sizer->AddSpacer(5);

	# The main layout for the dialog is vertical

	# Create the main sizer
	$sizer->Add( $self->{gotoline_label}, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$sizer->Add( $self->{gotoline_text},  0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$sizer->Add( $self->{status_line},    0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$sizer->AddSpacer(5);
	$sizer->Add( $button_sizer, 0, Wx::wxALIGN_RIGHT, 5 );
	$sizer->AddSpacer(5);

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
			my $line_number = $self->{gotoline_text}->GetValue;
			if ( $line_number !~ /^\d+$/ ) {
				$self->{status_line}->SetLabel( Wx::gettext('Not a line number!') );
				$self->{button_ok}->Enable(0);
				return;
			}

			my $editor = $self->current->editor;
			if ( $line_number > $self->{max_line_number} ) {
				$self->{status_line}->SetLabel( Wx::gettext('Out of range!') );
				$self->{button_ok}->Enable(0);
				return;
			}

			$self->{button_ok}->Enable(1);
			$self->{status_line}->SetLabel('');

			return;
		}
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			$_[0]->EndModal(Wx::wxID_CANCEL);

		}
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_ok},
		sub {
			my $self = shift;

			$self->EndModal(Wx::wxID_OK);

			my $line_number = $self->{gotoline_text}->GetValue;
			my $editor      = $self->current->editor;
			$line_number = $self->{max_line_number} if $line_number > $self->{max_line_number};
			$line_number--;
			$editor->goto_line_centerize($line_number);
		},
	);

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
	$self->{max_line_number} = $editor->GetLineCount;
	$self->{gotoline_label}
		->SetLabel( sprintf( Wx::gettext("Enter line number between 1 and %s:"), $self->{max_line_number} ) );

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
