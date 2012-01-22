package Padre::Wx::Dialog::OpenURL;

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

Padre::Wx::Dialog::OpenURL - a dialog for opening URLs

=head2 C<new>

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
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::CAPTION | Wx::CLOSE_BOX | Wx::SYSTEM_MENU
	);

	# Form Components

	# Input combobox for the URL
	$self->{openurl_text} = Wx::ComboBox->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
		Wx::CB_DROPDOWN
	);
	$self->{openurl_text}->SetSelection(-1);
	$self->{openurl_text}->SetFocus;

	# OK button (obviously)
	$self->{button_ok} = Wx::Button->new(
		$self,
		Wx::ID_OK,
		Wx::gettext("&OK"),
	);
	$self->{button_ok}->SetDefault;

	# Cancel button (obviously)
	$self->{button_cancel} = Wx::Button->new(
		$self,
		Wx::ID_CANCEL,
		Wx::gettext("&Cancel"),
	);

	# Form Layout

	# Sample URL label
	my $openurl_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('e.g.') . ' http://svn.perlide.org/padre/trunk/Padre/Makefile.PL',
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	# Separator line between the controls and the buttons
	my $line_1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	# Main button cluster
	my $button_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$button_sizer->Add( $self->{button_ok},     1, 0,        0 );
	$button_sizer->Add( $self->{button_cancel}, 1, Wx::LEFT, 5 );

	# The main layout for the dialog is vertical
	my $sizer_2 = Wx::BoxSizer->new(Wx::VERTICAL);
	$sizer_2->Add( $openurl_label,        0, 0,                                 0 );
	$sizer_2->Add( $self->{openurl_text}, 0, Wx::TOP | Wx::EXPAND,              5 );
	$sizer_2->Add( $line_1,               0, Wx::TOP | Wx::BOTTOM | Wx::EXPAND, 5 );
	$sizer_2->Add( $button_sizer,         1, Wx::ALIGN_RIGHT,                   5 );

	# Wrap it in a horizontal to create an top level border
	my $sizer_1 = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$sizer_1->Add( $sizer_2, 1, Wx::ALL | Wx::EXPAND, 5 );

	# Apply the top sizer in the stack to the window,
	# and tell the window and the sizer to alter size to fit
	# to each other correctly, regardless of the platform.
	# This type of sizing is NOT adaptive, so we must not use
	# Wx::RESIZE_BORDER with this dialog.
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
	my $ok    = $self->ShowModal;
	my $rv =
		( $ok == Wx::ID_OK )
		? $self->{openurl_text}->GetValue
		: undef;
	$self->Destroy;
	return $rv;
}

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
