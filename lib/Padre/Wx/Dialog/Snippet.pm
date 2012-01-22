package Padre::Wx::Dialog::Snippet;

use 5.008;
use strict;
use warnings;
use Params::Util            ();
use Padre::DB               ();
use Padre::Wx::FBP::Snippet ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::FBP::Snippet';





######################################################################
# Constructor

sub new {
	my $class  = shift;
	my $self   = $class->SUPER::new(@_);
	my $filter = $self->filter;
	my $select = $self->select;
	my $lock   = $self->main->lock( 'DB', 'UPDATE' );

	# Fill the filter
	$filter->Clear;
	$filter->Append(@$_) foreach $self->filters;
	$filter->SetSelection(0);

	# Populate the snippet list
	$self->refilter;

	# Reflow the layout and prepare to show
	$self->select->SetFocus;
	$self->GetSizer->SetSizeHints($self);

	return $self;
}





######################################################################
# Event Handlers

sub refresh {
	my $self  = shift;
	my $value = $self->value;
	$self->preview->SetValue($value);
}

sub refilter {
	my $self   = shift;
	my $lock   = $self->main->lock( 'DB', 'UPDATE' );
	my $select = $self->select;
	my $filter = $self->filter->GetClientData( $self->filter->GetSelection );
	$select->Clear;
	foreach my $name ( $self->names($filter) ) {
		$select->Append(@$name);
	}
	$select->SetSelection(0);
	$self->refresh;
}

sub insert_snippet {
	my $self   = shift;
	my $lock   = $self->main->lock('UPDATE');
	my $editor = $self->current->editor or return;
	$editor->insert_text( $self->value );
}





######################################################################
# Support Methods

sub filters {
	my $self    = shift;
	my $select  = Padre::DB->selectall_arrayref('SELECT DISTINCT category FROM snippets ORDER BY category');
	my @filters = (
		[ Wx::gettext('All'), '' ],
		map { [ $_->[0] => $_->[0] ] } @$select
	);
	return @filters;
}

sub names {
	my $self   = shift;
	my $filter = shift;
	my $where  = $filter ? 'WHERE category = ?' : '';
	my @param  = $filter ? ($filter) : ();
	my @names  = (
		map { [ $_->name => $_->id ] } Padre::DB::Snippets->select(
			"$where ORDER BY category, name",
			@param,
		)
	);
	return @names;
}

sub value {
	my $self   = shift;
	my $select = $self->select;
	my $id     = $select->GetClientData( $select->GetSelection );
	unless ( Params::Util::_POSINT($id) ) {
		return '';
	}

	# Load the snippet
	local $@;
	my $snippet = Padre::DB::Snippets->load($id);
	return $snippet ? $snippet->snippet : '';
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
