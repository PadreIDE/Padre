package Padre::Wx::Debugger::View;

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Wx       ();
use Padre::Wx::Icon ();
use Padre::Logger;

our $VERSION = '0.52';
our @ISA     = 'Wx::ListView';

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$main->bottom,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL
	);

#	my $list = Wx::ImageList->new( 16, 16 );
#	$list->Add( Padre::Wx::Icon::icon('status/padre-syntax-error') );
#	$list->Add( Padre::Wx::Icon::icon('status/padre-syntax-warning') );
#	$list->Add( Padre::Wx::Icon::icon('status/padre-syntax-ok') );
#	$self->AssignImageList( $list, Wx::wxIMAGE_LIST_SMALL );

	$self->InsertColumn( $_, _get_title($_) ) for 0 .. 1;

#	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
#		$self, $self,
#		sub {
#			$self->on_list_item_activated( $_[1] );
#		},
#	);
#	Wx::Event::EVT_RIGHT_DOWN(
#		$self, \&on_right_down,
#	);

	$self->Hide;

	return $self;
}

sub bottom {
	$_[0]->GetParent;
}

sub main {
	$_[0]->GetGrandParent;
}

sub gettext_label {
	Wx::gettext('Debugger');
}

sub clear {
	my $self = shift;

	# Remove all items from the tool
	$self->DeleteAllItems;

	return;
}

sub set_column_widths {
	my $self      = shift;
	my $ref_entry = shift;

	return;
}

#####################################################################
# Event Handlers

sub on_list_item_activated {
	my $self   = shift;
	my $event  = shift;
	my $editor = Padre::Current->main($self)->current->editor;
	my $line   = $event->GetItem->GetText;

	if (   not defined($line)
		or $line !~ /^\d+$/o
		or $editor->GetLineCount < $line )
	{
		return;
	}

	$self->select_problem( $line - 1 );

	return;
}

sub _get_title {
	my $c = shift;

	return Wx::gettext('Variable')     if $c == 0;
	return Wx::gettext('Value')        if $c == 1;

	die "invalid value '$c'";
}


sub relocale {
	my $self = shift;

	for my $i ( 0 .. 1 ) {
		my $col = $self->GetColumn($i);
		$col->SetText( _get_title($i) );
		$self->SetColumn( $i, $col );
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
