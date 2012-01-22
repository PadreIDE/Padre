package Padre::Wx::Util;

# Stores utility functions that are Wx-specific so that we don't need to
# put Wx-specific code into Padre::Util.

use 5.008;
use strict;
use warnings;
use Padre::Wx;

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';

sub tidy_list {
	my $list = shift;

	require Padre::Wx;
	for ( 0 .. $list->GetColumnCount - 1 ) {
		$list->SetColumnWidth( $_, Wx::LIST_AUTOSIZE_USEHEADER() );
		my $header_width = $list->GetColumnWidth($_);
		$list->SetColumnWidth( $_, Wx::LIST_AUTOSIZE() );
		my $column_width = $list->GetColumnWidth($_);
		$list->SetColumnWidth( $_, ( $header_width >= $column_width ) ? $header_width : $column_width );
	}

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
