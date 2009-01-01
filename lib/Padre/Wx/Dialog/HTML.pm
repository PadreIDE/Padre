package Padre::Wx::Dialog::HTML;

# Provides a base class for dialogs that are built using dynamic HTML

use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::HtmlWindow ();

our $VERSION = '0.22';
our @ISA     = 'Wx::Frame';

sub new {
	my $class = shift;

	# Get the params, and apply defaults
	my %param = (
		parent => undef,
		id     => -1,
		style  => Wx::wxDEFAULT_FRAME_STYLE,
		title  => '',
		pos    => [-1, -1],
		size   => [-1, -1],
		@_,
	);

	# Create the dialog object
	my $self = $class->SUPER::new(
		$param{parent},
		$param{id},
		$param{title},
		$param{pos},
		$param{size},
		$param{style},
	);
	%$self = %param;

	# Create the panel to hold the HTML widget
	$self->{panel} = Wx::Panel->new( $self, -1 );
	$self->{sizer} = Wx::GridSizer->new( 1, 1, 10, 10 );

	# Add the HTML renderer to the frame
	$self->{renderer} = Padre::Wx::HtmlWindow->new( $self->{panel}, -1 );
	$self->{sizer}->Add(
		$self->{renderer},
		1, # Growth proportion
		Wx::wxEXPAND,
		5, # Border size
	);

	# Load the HTML content
	$self->{renderer}->SetPage( $self->{html} );

	# Tie the sizing to the panel
	$self->{panel}->SetSizer( $self->{sizer} );
	$self->{panel}->SetAutoLayout(1);

	return $self;
}

1;
