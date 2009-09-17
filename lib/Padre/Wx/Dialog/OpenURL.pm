package Padre::Wx::Dialog::OpenURL;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();

our $VERSION = '0.46';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};

=pod

=head2 new

  my $find = Padre::Wx::Dialog::OpenURL->new($main);

Create and return a C<Padre::Wx::Dialog::OpenURL> "Open URL" widget.

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Open URL'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION
		| Wx::wxCLOSE_BOX
		| Wx::wxSYSTEM_MENU
	);

	# Form Components

	# Input combobox for the URL
	$self->{openurl_text} = Wx::ComboBox->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
		Wx::wxCB_DROPDOWN
	);
	$self->{openurl_text}->SetSelection(-1);

	# OK button (obviously)
	$self->{button_ok} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		"",
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_ok},
		sub {
			$_[0]->button_ok;
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

	# Form Layout

	# Sample URL label
	my $openurl_label = Wx::StaticText->new(
		$self,
		-1,
		"http://svn.perlide.org/padre/trunk/Padre/Makefile.PL",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	# Separator line between the controls and the buttons
	my $line_1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	# Main button cluster
	my $button_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	$button_sizer->Add( $self->{button_ok}, 1, 0, 0 );
	$button_sizer->Add( $self->{button_cancel}, 1, Wx::wxLEFT, 5 );

	# The main layout for the dialog is vertical
	my $sizer_2 = Wx::BoxSizer->new( Wx::wxVERTICAL );
	$sizer_2->Add( $openurl_label, 0, 0, 0 );
	$sizer_2->Add( $self->{openurl_text}, 0, Wx::wxTOP | Wx::wxEXPAND, 5 );
	$sizer_2->Add( $line_1, 0, Wx::wxTOP | Wx::wxBOTTOM | Wx::wxEXPAND, 5 );
	$sizer_2->Add( $button_sizer, 1, Wx::wxALIGN_RIGHT, 5 );

	# Wrap it in a horizontal to create an top level border
	my $sizer_1 = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
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

=head2 ok_button

  $self->ok_button

Attempt to open the specified URL

=cut

sub ok_button {
	my $self = shift;
	$self->Hide;

	# Leave a note for the person who will implement the rest of
	# the Open URL feature. Far better than dying :)
	$self->main->message(
		Wx::gettext('This feature has not been implemented by Sewi'),
		Wx::gettext('Search'),
	);

	# As we leave the Find dialog return the user to the current editor
	# window so they don't need to click it.
	my $editor = $self->current->editor;
	if ( $editor ) {
		$editor->SetFocus;
	}

	# We don't reuse this dialog
	$self->Destroy;	
}

=pod

=head2 cancel_button

  $self->cancel_button

Hide dialog when pressed cancel button.

=cut

sub cancel_button {
	my $self = shift;
	$self->Hide;

	# As we leave the Find dialog return the user to the current editor
	# window so they don't need to click it.
	my $editor = $self->current->editor;
	if ( $editor ) {
		$editor->SetFocus;
	}

	# We don't reuse this dialog
	$self->Destroy;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
