package t::lib::Padre::NullWindow;

# This is an empty null main window, so that we can test multi-thread
# code without having to actually build all of the Padre main window.

use 5.008;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Logger;

our $VERSION = '0.64';
our @ISA     = qw{
	Padre::Wx::Role::Conduit
	Wx::Frame
};

# NOTE: This is just a test window so don't add Wx::gettext
use constant NAME => 'Padre Null Test Window';

sub new {
	TRACE($_[0]) if DEBUG;
	my $class = shift;

	# Basic constructor
	my $self  = $class->SUPER::new(
		undef, -1,
		NAME,
		[ -1, -1 ],
		[ -1, -1 ],
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Set various properties
	$self->SetTitle(NAME);
	$self->SetMinSize(
		Wx::Size->new( 100, 100 ),
	);

	# Register outself as the event conduit from child workers
	# to the parent thread.
	$self->conduit_init;
	
	return $self;
}

1;
