package Padre::Wx::TreeCtrl;

# A general use TreeCtrl that adds a variety of convenience methods

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.69';
our @ISA     = 'Wx::TreeCtrl';

# Iterate through the children to find one with specific text.
# Return undef if no child with that text exists.
sub GetChildByText {
	my $self = shift;
	my $item = shift;
	my $text = shift;

	# Start with the first child
	my ($child, $cookie) = $self->GetFirstChild( $item );

	while ( $cookie ) {
		# Is the current child the one we want?
		if ( $self->GetItemText($child) eq $text ) {
			return $child;
		}

		# Get the next child if there is one
		($child, $cookie) = $self->GetNextChild( $item, $cookie );
	}

	# Either no children, or no more children
	return undef;
}

1;
