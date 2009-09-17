package Padre::Wx::Dialog::OpenURL;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();

# Temporarily needed, because wxGlade expects exported symbols
use Wx qw[:everything];

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
		wxDefaultPosition,
		wxDefaultSize,
		[],
		wxCB_DROPDOWN
	);
	$self->{openurl_text}->SetSelection(-1);

	# OK button (obviously)
	$self->{button_ok} = Wx::Button->new(
		$self,
		wxID_OK,
		"",
	);

	# Cancel button (obviously)
	$self->{button_cancel} = Wx::Button->new(
		$self,
		wxID_CANCEL,
		"",
	);

	# Form Layout

	# Sample URL label
	my $openurl_label = Wx::StaticText->new(
		$self,
		-1,
		"http://svn.perlide.org/padre/trunk/Padre/Makefile.PL",
		wxDefaultPosition,
		wxDefaultSize,
	);

	# Separator line between the controls and the buttons
	my $line_1 = Wx::StaticLine->new(
		$self,
		-1,
		wxDefaultPosition,
		wxDefaultSize,
	);

	# Main button cluster
	my $button_sizer = Wx::BoxSizer->new( wxHORIZONTAL );
	$button_sizer->Add( $self->{button_ok}, 1, 0, 0 );
	$button_sizer->Add( $self->{button_cancel}, 1, wxLEFT, 5 );

	# The main layout for the dialog is vertical
	my $sizer_2 = Wx::BoxSizer->new( wxVERTICAL );
	$sizer_2->Add( $openurl_label, 0, 0, 0 );
	$sizer_2->Add( $self->{openurl_text}, 0, wxTOP | wxEXPAND, 5 );
	$sizer_2->Add( $line_1, 0, wxTOP | wxBOTTOM | wxEXPAND, 5 );
	$sizer_2->Add( $button_sizer, 1, wxALIGN_RIGHT, 5 );

	# Wrap it in a horizontal to create an top level border
	my $sizer_1 = Wx::BoxSizer->new( wxHORIZONTAL );
	$sizer_1->Add( $sizer_2, 1, wxALL | wxEXPAND, 5 );

	# Apply the top sizer in the stack to the window,
	# and tell the window and the sizer to alter size to fit
	# to each other correctly, regardless of the platform.
	# This type of sizing is NOT adaptive, so we must not use
	# wxRESIZE_BORDER with this dialog.
	$self->SetSizer($sizer_1);
	$sizer_1->Fit($self);
	$self->Layout;

	return $self;
}

1;
