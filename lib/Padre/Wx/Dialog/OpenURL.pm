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

	return $self;
}

1;
