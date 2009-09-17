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

	$self->{button_ok} = Wx::Button->new(
		$self,
		wxID_OK,
		"",
	);

	$self->{button_cancel} = Wx::Button->new(
		$self,
		wxID_CANCEL,
		"",
	);

	# Form Layout

	my $sizer_1 = Wx::BoxSizer->new(wxHORIZONTAL);
	my $sizer_2 = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $openurl_label = Wx::StaticText->new($self, -1, "http://svn.perlide.org/padre/trunk/Padre/Makefile.PL", wxDefaultPosition, wxDefaultSize, );
	$sizer_2->Add($openurl_label, 0, 0, 0);
	$sizer_2->Add($self->{openurl_text}, 0, wxTOP|wxEXPAND, 5);
	my $line_1 = Wx::StaticLine->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$sizer_2->Add($line_1, 0, wxTOP|wxBOTTOM|wxEXPAND, 5);
	$button_sizer->Add($self->{button_ok}, 1, 0, 0);
	$button_sizer->Add($self->{button_cancel}, 1, wxLEFT, 5);
	$sizer_2->Add($button_sizer, 1, wxALIGN_RIGHT, 5);
	$sizer_1->Add($sizer_2, 1, wxALL|wxEXPAND, 5);
	$self->SetSizer($sizer_1);
	$sizer_1->Fit($self);
	$self->Layout();

	return $self;
}

1;
