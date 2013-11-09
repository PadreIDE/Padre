package Padre::Locale::Format;

# Implements regional formatting logic for numbers etc

use 5.008;
use strict;
use warnings;
use Params::Util ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.95';





######################################################################
# Format Registry

my %FORMAT = (
	en_GB => {
		number_decimal_symbol        => '.',
		number_digit_grouping        => '333',
		number_digit_grouping_symbol => ',',
		number_negative_symbol       => '-',
		number_negative_format       => '-1.1',
	},
);





######################################################################
# Format Functions

sub integer {
	my $text    = shift;
	my $rfc4646 = shift || 'en_GB';
	my $format  = $FORMAT{$rfc4646} || $FORMAT{en_GB};

	# Shortcut unusual cases
	unless ( defined Params::Util::_STRING($text) ) {
		return '';
	}
	unless ( $text =~ /^-?\d+\z/ ) {
		return $text;
	}

	# Is the number negative
	my $negative = $text < 0;
	$text = abs($text);

	# Does this locale support grouping
	if ( $format->{number_digit_grouping} eq '333' ) {

		# Apply 123,456,789 style grouping
		my $g = $format->{number_digit_grouping_symbol};
		$text =~ s/(\d)(\d\d\d)$/$1$g$2/;
		while (1) {
			$text =~ s/(\d)(\d\d\d\Q$g\E)/$1$g$2/ or last;
		}
	}

	# Apply negation formatting
	if ($negative) {
		if ( $format->{number_negative_format} eq '- 1.1' ) {
			$text = "$format->{number_negative_symbol} $text";
		} else {

			# Default to negative format '-1.1'
			$text = "$format->{number_negative_symbol}$text";
		}
	}

	return $text;
}

sub bytes {
	my $text    = shift;
	my $rfc4646 = shift || 'en_GB';
	my $format  = $FORMAT{$rfc4646} || $FORMAT{en_GB};

	# Shortcut unusual cases
	unless ( defined Params::Util::_STRING($text) ) {
		return '';
	}
	unless ( $text =~ /^\d+\z/ ) {
		return $text;
	}

	if ( $text > 8192000000000 ) {
		return sprintf( '%0.1f', $text / 1099511627776 ) . "TB";
	} elsif ( $text > 8192000000 ) {
		return sprintf( '%0.1f', $text / 1073741824 ) . "GB";
	} elsif ( $text > 8192000 ) {
		return sprintf( '%0.1f', $text / 1048576 ) . "MB";
	} elsif ( $text > 8192 ) {
		return sprintf( '%0.1f', $text / 1024 ) . "kB";
	} else {
		return $text . "B";
	}
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
