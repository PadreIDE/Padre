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

	#----- Form Components

	# Input text control for the line number
	$self->{gotoline_text} = Wx::TextCtrl->new(
			$self,                 -1, '',
			Wx::wxDefaultPosition, Wx::wxDefaultSize,
	);

	# OK button (obviously)
	$self->{button_ok} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		Wx::gettext("&OK"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_ok},
		sub {
			$_[0]->ok_button;
		},
	);
	$self->{button_ok}->SetDefault;

	# Cancel button (obviously)
	$self->{button_cancel} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		Wx::gettext("&Cancel"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			$_[0]->cancel_button;
		}
	);

	#----- Form Layout

	# Sample URL label
	$self->{gotoline_label} = Wx::StaticText->new(
		$self,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	# Main button cluster
	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $self->{button_ok},     1, 0,          0 );
	$button_sizer->Add( $self->{button_cancel}, 1, Wx::wxLEFT, 5 );

	# The main layout for the dialog is vertical
	my $sizer_2 = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$sizer_2->Add( $self->{gotoline_label},        0, 0,                                       0 );
	$sizer_2->Add( $self->{gotoline_text}, 0, Wx::wxTOP | Wx::wxEXPAND,                5 );
	$sizer_2->Add( $button_sizer,         1, Wx::wxALIGN_RIGHT,                       5 );

	# Wrap it in a horizontal to create an top level border
	my $sizer_1 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizer_1->Add( $sizer_2, 1, Wx::wxALL | Wx::wxEXPAND, 5 );

	# Apply the top sizer in the stack to the window,
	# and tell the window and the sizer to alter size to fit
	# to each other correctly, regardless of the platform.
	# This type of sizing is NOT adaptive, so we must not use
	# Wx::wxRESIZE_BORDER with this dialog.
	$self->SetSizer($sizer_1);
	$sizer_1->Fit($self);
	$self->Layout;

	return $self;
}

=pod

=head2 C<modal>

  my $url = Padre::Wx::Dialog::OpenURL->modal($main);

Single-shot modal dialog call to get a URL from the user.

Returns a string if the user clicks B<OK> (it may be a null string if they did
not enter anything).

Returns C<undef> if the user hits the cancel button.

=cut

sub modal {
	my $class = shift;
	my $self  = $class->new(@_);
	
	my $editor      = $self->current->editor;
	my $max         = $editor->GetLineCount;
	$self->{gotoline_label}->SetLabel(
		sprintf( Wx::gettext("Line number between (1..%s):"), $max ));
	
	my $ok    = $self->ShowModal;

	return;
}

=pod

=head2 C<ok_button>

  $self->ok_button

Attempt to open the specified URL

=cut

sub ok_button {
	my $self = shift;

	$self->EndModal(Wx::wxID_OK);
	
#	return if not defined $line_number or $line_number !~ /^\d+$/;
#
#	$line_number = $max if $line_number > $max;
#	$line_number--;
#	$editor->goto_line_centerize($line_number);
}

=pod

=head2 C<cancel_button>

  $self->cancel_button

Hide dialog when pressed cancel button.

=cut

sub cancel_button {
	$_[0]->EndModal(Wx::wxID_CANCEL);
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
