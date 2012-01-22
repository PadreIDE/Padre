package Padre::Wx::Dialog::RefactorSelectFunction;

# stolen from Padre::Wx::Dialog::SessionManager

# This file is part of Padre, the Perl ide.

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Icon ();

our $VERSION = '0.94';
our @ISA     = 'Wx::Dialog';

use Class::XSAccessor {
	accessors => {
		_butselect   => '_butselect',   # select
		_currow      => '_currow',      # current list row number
		_curname     => '_curname',     # name of current session selected
		_list        => '_list',        # list on the left of the pane
		_sortcolumn  => '_sortcolumn',  # column used for list sorting
		_sortreverse => '_sortreverse', # list sorting is reversed
		_vbox        => '_vbox',        # the window vbox sizer
	}
};

# -- constructor

# pass in array reference for functions
sub new {
	my ( $class, $parent, $functions ) = @_;

	# create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext('Select Function'),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_FRAME_STYLE | Wx::TAB_TRAVERSAL,
	);

	$self->{cancelled} = 0;
	$self->{functions} = $functions;
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# create dialog
	$self->_create;



	return $self;
}

sub get_function_name {
	my $self = shift;
	return $self->_curname;
}

sub show {
	my $self = shift;

	$self->_refresh_list;
	$self->_select_first_item;
	$self->ShowModal;
}

sub _create {
	my $self = shift;

	# create vertical box that will host all controls
	my $vbox = Wx::BoxSizer->new(Wx::VERTICAL);
	$self->SetSizer($vbox);
	$self->CenterOnParent;

	#$self->SetMinSize( [ 640, 480 ] );
	$self->_vbox($vbox);

	$self->_create_list;
	$self->_create_buttons;
	$self->_list->SetFocus;
}

sub _create_list {
	my $self = shift;
	my $vbox = $self->_vbox;

	# title label
	my $label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext("Select which subroutine you want the new subroutine\ninserted before.")
	);
	$vbox->Add( $label, 0, Wx::ALL, 5 );

	# create list
	my $list = Wx::ListView->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LC_REPORT | Wx::LC_SINGLE_SEL,
	);
	$list->InsertColumn( 0, Wx::gettext('Function') );
	$self->_list($list);

	# install event handler
	Wx::Event::EVT_LIST_ITEM_SELECTED( $self, $list, \&_on_list_item_selected );
	Wx::Event::EVT_LIST_ITEM_ACTIVATED( $self, $list, \&_on_list_item_activated );
	Wx::Event::EVT_LIST_COL_CLICK( $self, $list, \&_on_list_col_click );

	# pack the list
	$vbox->Add( $list, 1, Wx::ALL | Wx::EXPAND, 5 );
}


sub _create_buttons {
	my $self = shift;

	# the hbox
	my $hbox = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$self->_vbox->Add( $hbox, 0, Wx::ALL | Wx::EXPAND, 5 );

	# the buttons
	my $bs = Wx::Button->new( $self, -1,            Wx::gettext('Select') );
	my $bc = Wx::Button->new( $self, Wx::ID_CANCEL, Wx::gettext('Cancel') );
	$self->_butselect($bs);
	Wx::Event::EVT_BUTTON( $self, $bs, \&_on_butselect_clicked );
	Wx::Event::EVT_BUTTON( $self, $bc, \&_on_butclose_clicked );
	$hbox->Add( $bs, 0, Wx::ALL, 5 );
	$hbox->AddStretchSpacer;
	$hbox->Add( $bc, 0, Wx::ALL, 5 );
}

sub _refresh_list {
	my ( $self, $column, $reverse ) = @_;

	# default sorting
	$column  ||= 0;
	$reverse ||= 0;


	my @sorted;
	if ($reverse) {
		@sorted = sort { uc($b) cmp uc($a) } @{ $self->{functions} };
	} else {
		@sorted = sort { uc($a) cmp uc($b) } @{ $self->{functions} };
	}

	# clear list & fill it again
	my $list = $self->_list;
	$list->DeleteAllItems;

	foreach my $function (@sorted) {

		# inserting the session in the list
		my $item = Wx::ListItem->new;
		$item->SetId(0);
		$item->SetColumn(0);
		$item->SetText($function);
		my $idx = $list->InsertItem($item);
	}

	# auto-resize columns
	my $flag =
		$list->GetItemCount
		? Wx::LIST_AUTOSIZE
		: Wx::LIST_AUTOSIZE_USEHEADER;
	$list->SetColumnWidth( $_, $flag ) for 0 .. 2;

	# making sure the list can show all columns
	my $width = 15; # taking vertical scrollbar into account
	$width += $list->GetColumnWidth($_) for 0 .. 2;
	$list->SetMinSize( [ $width, -1 ] );
}

sub _select_first_item {
	my ($self) = @_;

	# select first item in the list
	my $list = $self->_list;

	if ( $list->GetItemCount ) {
		my $item = $list->GetItem(0);
		$item->SetState(Wx::LIST_STATE_SELECTED);
		$list->SetItem($item);
	} else {

		# remove current selection
		$self->_currow(undef);
		$self->_curname(undef);
	}
}

sub _on_butclose_clicked {

	my $self = shift;
	$self->{cancelled} = 1;
	$self->Destroy;
}

#
# $self->_on_butselect_clicked;
#
# handler called when the open button has been clicked.
#
sub _on_butselect_clicked {
	my $self = shift;

	# prevents crash if user double-clicks on list
	# item and tries to click buttons
	#$self->_butdelete->Disable;
	$self->_butselect->Disable;
	$self->Destroy;
}

#
# $self->_on_list_col_click;
#
# handler called when a column has been clicked, to reorder the list.
#
sub _on_list_col_click {
	my ( $self, $event ) = @_;
	my $col = $event->GetColumn;

	my $prevcol  = $self->_sortcolumn  || 0;
	my $reversed = $self->_sortreverse || 0;
	$reversed = $col == $prevcol ? !$reversed : 0;
	$self->_sortcolumn($col);
	$self->_sortreverse($reversed);
	$self->_refresh_list( $col, $reversed );
}

#
# $self->_on_list_item_selected( $event );
#
# handler called when a list item has been selected. it will in turn update
# the buttons state.
#
# $event is a Wx::ListEvent.
#
sub _on_list_item_selected {
	my ( $self, $event ) = @_;

	my $name = $event->GetLabel;
	$self->_curname($name);             # storing selected session
	$self->_currow( $event->GetIndex ); # storing selected row

}

#
# $self->_on_list_item_activated( $event );
#
# handler called when a list item has been double clicked. it will automatically open
# the selected session
#
# $event is a Wx::ListEvent.
#
sub _on_list_item_activated {
	my ( $self, $event ) = @_;

	$self->_on_list_item_selected($event);
	$self->_on_butselect_clicked;
}




1;

__END__

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
