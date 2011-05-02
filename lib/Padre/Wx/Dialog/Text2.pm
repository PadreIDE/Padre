package Padre::Wx::Dialog::Text2;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::Text;

our $VERSION = '0.85';
our @ISA     = 'Padre::Wx::FBP::Text';





######################################################################
# Original API Emulation

sub show {
	my $class = shift;
	my $main  = shift;
	my $title = shift || '';
	my $text  = shift || '';

	# Create the dialog
	my $self  = $class->new($main);
	$self->SetTitle($title);
	$self->text->SetValue($text);
	$self->close->SetFocus;

	# Display the dialog
	$self->CentreOnParent;
	$self->ShowModal;
}

1;
