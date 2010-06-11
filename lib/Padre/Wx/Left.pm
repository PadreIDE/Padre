package Padre::Wx::Left;

# The left-hand notebook

use 5.008;
use strict;
use warnings;
use Padre::Constant ();
use Padre::Wx       ();

our $VERSION = '0.64';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::AuiNotebook
};

sub new {
	my $class  = shift;
	my $main   = shift;
	my $aui    = $main->aui;
	my $unlock = $main->config->main_lockinterface ? 0 : 1;

	# Create the basic object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::wxDefaultPosition,
		Wx::Size->new( 200, 500 ), # Used when floating
		Wx::wxAUI_NB_SCROLL_BUTTONS | Wx::wxAUI_NB_TOP | Wx::wxBORDER_NONE
	);

	# Add ourself to the window manager
	$aui->AddPane(
		$self,
		Padre::Wx->aui_pane_info(
			Name           => 'left',
			CaptionVisible => $unlock,
			Floatable      => $unlock,
			Dockable       => $unlock,
			Movable        => $unlock,
			Resizable      => 1,
			PaneBorder     => 0,
			CloseButton    => 0,
			DestroyOnClose => 0,
			MaximizeButton => 0,
			Position       => 4,
			Layer          => 2,
			)->Left->Hide,
	);
	$aui->caption(
		left => Wx::gettext('Project Tools'),
	);

	return $self;
}





#####################################################################
# Page Management

sub show {
	my $self = shift;
	my $page = shift;

	# Are we currently showing the page
	my $position = $self->GetPageIndex($page);
	if ( $position >= 0 ) {

		# Already showing, switch to it
		$self->SetSelection($position);
		return;
	}

	# Add the page
	$self->InsertPage(
		0,
		$page,
		$page->gettext_label,
		1,
	);
	$page->Show;
	$self->Show;
	$self->aui->GetPane($self)->Show;

	return;
}

sub hide {
	my $self     = shift;
	my $page     = shift;
	my $position = $self->GetPageIndex($page);
	unless ( $position >= 0 ) {

		# Not showing this
		return 1;
	}

	# Remove the page
	$page->Hide;
	$self->RemovePage($position);

	# Is this the last page?
	if ( $self->GetPageCount == 0 ) {
		$self->Hide;
		$self->aui->GetPane($self)->Hide;
	}

	return;
}

# This has a refresh so we can do content-adaptive labels
sub refresh {
	my $self = shift;
	foreach my $i ( 0 .. $self->GetPageCount - 1 ) {
		$self->SetPageText( $i, $self->GetPage($i)->gettext_label );
	}
	return;
}

sub relocale {
	my $self = shift;
	foreach my $i ( 0 .. $self->GetPageCount - 1 ) {
		$self->SetPageText( $i, $self->GetPage($i)->gettext_label );
	}
	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
