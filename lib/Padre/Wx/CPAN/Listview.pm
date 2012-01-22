package Padre::Wx::CPAN::Listview;

use 5.008;
use strict;
use warnings;
use Params::Util qw{_INSTANCE};
use Padre::Wx       ();
use Padre::Wx::Icon ();

our $VERSION = '0.94';
our @ISA     = 'Wx::ListView';

sub new {
	my $class = shift;
	my $frame = shift;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$frame,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LC_REPORT | Wx::LC_SINGLE_SEL
	);
	$self->{cpan} = $frame->cpan;

	my $imagelist = Wx::ImageList->new( 14, 7 );
	$imagelist->Add( Padre::Wx::Icon::icon('status/padre-syntax-error') );
	$imagelist->Add( Padre::Wx::Icon::icon('status/padre-syntax-warning') );
	$self->AssignImageList( $imagelist, Wx::IMAGE_LIST_SMALL );

	$self->InsertColumn( 0, Wx::gettext('Status') );

	$self->SetColumnWidth( 0, 750 );

	Wx::Event::EVT_LIST_ITEM_ACTIVATED( $self, $self, \&on_list_item_activated );

	return $self;
}

sub bottom {
	$_[0]->GetParent;
}

sub main {
	$_[0]->GetGrandParent;
}

sub clear {
	my $self = shift;

	$self->DeleteAllItems;

	return;
}

sub set_column_widths {
	my $self = shift;

	my $width0 = $self->GetCharWidth * length( Wx::gettext('Status') ) + 16;
	my $width1 = $self->GetSize->GetWidth - $width0;

	#my $width1 = $self->GetCharWidth * ( length("blabla") + 2 );
	#my $width2 = $self->GetSize->GetWidth - $width0 - $width1 - $self->GetCharWidth * 4;

	$self->SetColumnWidth( 0, $width0 );
	$self->SetColumnWidth( 1, $width1 );

	#$self->SetColumnWidth( 2, $width2 );

	return;
}

#####################################################################
# Event Handlers

sub show_rows {
	my ( $self, $regex ) = @_;

	$self->clear;
	my $cpan    = $self->{cpan};
	my $c       = 10;
	my $modules = $cpan->get_modules($regex);
	foreach my $module ( reverse sort @$modules ) {
		my $idx = $self->InsertStringImageItem( 0, $module, 0 );

		#$self->SetItem( $idx, 1,  Wx::gettext('Warning')  );
		#$self->SetItem( $idx, 1, $module );
		$self->SetItemData( $idx, 1 );
	}
}

sub on_list_item_activated {
	my $self  = shift;
	my $event = shift;
	my $line  = $event->GetItem->GetText;
	print STDERR "L: $line\n";
	$self->{cpan}->install($line);

	#	my $item = $self->GetFocusedItem;
	#	print STDERR "I ", $item, "\n";
	#	print STDERR "T ", $self->GetItemText($item), "\n";
	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
