package Padre::Locale::Format;

# Implements regional formatting logic for numbers etc

use 5.008;
use strict;
use warnings;

our $VERSION    = '0.95';
our $COMPATIBLE = '0.95';





######################################################################
# Format Registry

my %FORMAT = (
	en_GB => {
		number_digit_grouping        => '33',
		number_digit_grouping_symbol => ',',
	},
);





######################################################################
# Format Functions

sub integer {
	my $text    = shift;
	my $rfc4646 = shift || 'en_GB';
	my $format  = $FORMAT{$rfc4646} || $FORMAT{en_GB};

	# Does this locale support grouping
	unless ( $format->{number_digit_grouping} ) {
		return $text;
	}

	# Find the symbol for this locale
	my $s = $format->{number_digit_grouping_symbol};
	$s = ',' unless defined $s;

	# Apply the first grouping
	unless ( $text =~ s/(\d)(\d\d\d)$/$1$s$2/ ) {
		return $text;
	}

	# TODO Disabled until a format exists that needs it
	# Apply 12,34,56,789 style grouping
	# if ( $format->{number_digit_grouping} eq '223' ) {
		# while ( 1 ) {
			# $text =~ s/(\d)(\d\d)$s/$1$s$2/ or last;
		# }
		# return $text;
	# }

	# Apply 123,456,789 style grouping
	while ( 1 ) {
		$text =~ s/(\d)(\d\d\d)$s/$1$s$2/ or last;
	}
	return $text;
}

1;
