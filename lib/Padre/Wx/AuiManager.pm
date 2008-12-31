package Padre::Wx::AuiManager;

# Sub-class of Wx::AuiManager that implements various custom
# tweaks and behaviours.

use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.22';
our @ISA     = 'Wx::AuiManager';

# The custom AUI Manager takes the parent window as a param
sub new {
	my $class = shift;
	my $self  = $class->SUPER::new;
	
	 # Wx::AuiManager seems to bless into itself but we want to subclass it
	bless $self, $class;

	# Set the managed window
	$self->SetManagedWindow($_[0]);

	# Set/fix the flags
	# Do NOT use hints other than Rectangle on Linux/GTK
	# or the app will crash.
	my $flags = $self->GetFlags;
	$flags &= ~Wx::wxAUI_MGR_TRANSPARENT_HINT;
	$flags &= ~Wx::wxAUI_MGR_VENETIAN_BLINDS_HINT;
	$self->SetFlags( $flags ^ Wx::wxAUI_MGR_RECTANGLE_HINT );

	return $self;
}

sub relocale {
	my $self = shift;

	# Update various pane labels
	$self->GetPane('sidepane')->Caption( Wx::gettext("Subs") );
	$self->GetPane('bottompane')->Caption( Wx::gettext("Output") );

	return $self;
}

1;
