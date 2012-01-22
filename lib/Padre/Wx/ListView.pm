package Padre::Wx::ListView;

# A custom subclass of Wx::ListView with additional convenience methods

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.94';
our @ISA     = 'Wx::ListView';

sub lock_update {
	Wx::WindowUpdateLocker->new($_[0]);
}

# Set all columns at once and autosize
sub init {
	my $self    = shift;
	my @headers = @_;
	my $lock    = $self->lock_update;

	# Add the columns
	foreach my $i ( 0 .. $#headers ) {
		$self->InsertColumn( $i, $headers[$i] );
		$self->SetColumnWidth( $i, Wx::LIST_AUTOSIZE );
	}

	# Resize to the headers, ensuring the last column is the longest
	foreach my $i ( 0 .. $#headers ) {
		$self->SetColumnWidth( $i, Wx::LIST_AUTOSIZE_USEHEADER );
	}

	return;
}

sub set_item_bold {
	my $self   = shift;
	my $item   = $self->GetItem(shift);
	my $weight = shift() ? Wx::FONTWEIGHT_BOLD : Wx::FONTWEIGHT_NORMAL;
	my $font   = $item->GetFont;
	$font->SetWeight($weight);
	$item->SetFont($font);
	$self->SetItem($item);
	return 1;
}

sub tidy {
	my $self = shift;
	my $lock = $self->lock_update;
	foreach my $i ( 0 .. $self->GetColumnCount - 1 ) {
		$self->SetColumnWidth( $i, Wx::LIST_AUTOSIZE_USEHEADER );
		my $header = $self->GetColumnWidth($i);
		$self->SetColumnWidth( $i, Wx::LIST_AUTOSIZE );
		if ( $header > $self->GetColumnWidth($i) ) {
			$self->SetColumnWidth( $i, $header );
		}
	}
	return;
}

sub tidy_headers {
	my $self = shift;
	my $lock = $self->lock_update;
	foreach my $i ( 0 .. $self->GetColumnCount - 1 ) {
		$self->SetColumnWidth( $i, Wx::LIST_AUTOSIZE_USEHEADER );
	}
	return;
}

sub tidy_content {
	my $self = shift;
	my $lock = $self->lock_update;
	foreach my $i ( 0 .. $self->GetColumnCount - 1 ) {
		$self->SetColumnWidth( $i, Wx::LIST_AUTOSIZE );
	}
	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
