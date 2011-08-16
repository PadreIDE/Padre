package Padre::Wx::Debug;

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Wx       ();
use Padre::Wx::Icon ();
use Padre::Logger;

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::ListView
};





#####################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->right;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$panel,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL
	);

	$self->InsertColumn( $_, _get_title($_) ) for 0 .. 1;

	$self->Hide;

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'right';
}

sub view_label {
	shift->gettext_label;
}

sub view_close {
	$_[0]->main->show_debug(0);
}





######################################################################
# Event Handlers

sub on_list_item_activated {
	my $self   = shift;
	my $event  = shift;
	my $editor = $self->main->current->editor;
	my $line   = $event->GetItem->GetText;

	if (   not defined($line)
		or $line !~ /^\d+$/o
		or $editor->GetLineCount < $line )
	{
		return;
	}

	# $self->select_problem( $line - 1 );

	return;
}




######################################################################
# General Methods

sub gettext_label {
	Wx::gettext('Debugger');
}

sub clear {
	$_[0]->DeleteAllItems;
}

sub set_column_widths {
	return;
}

sub relocale {
	my $self = shift;

	foreach my $i ( 0 .. 1 ) {
		my $col = $self->GetColumn($i);
		$col->SetText( _get_title($i) );
		$self->SetColumn( $i, $col );
	}

	return;
}

sub _get_title {
	my $c = shift;
	return Wx::gettext('Variable') if $c == 0;
	return Wx::gettext('Value')    if $c == 1;
	die "invalid value '$c'";
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
