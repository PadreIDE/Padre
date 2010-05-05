package Padre::Wx::Right;

# The right-hand notebook

use 5.008;
use strict;
use warnings;
use Padre::Constant ();
use Padre::Wx       ();

our $VERSION = '0.60';
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
		Wx::Size->new( 160, 500 ), # Used when floating
		Wx::wxAUI_NB_SCROLL_BUTTONS | Wx::wxAUI_NB_TOP | Wx::wxBORDER_NONE | Wx::wxAUI_NB_CLOSE_ON_ACTIVE_TAB
	);

	# Add ourself to the window manager
	$aui->AddPane(
		$self,
		Padre::Wx->aui_pane_info(
			Name           => 'right',
			Resizable      => 1,
			PaneBorder     => 0,
			CloseButton    => 0,
			DestroyOnClose => 0,
			MaximizeButton => 0,
			Position       => 3,
			Layer          => 3,
			CaptionVisible => $unlock,
			Floatable      => $unlock,
			Dockable       => $unlock,
			Movable        => $unlock,
			)->Right->Hide,
	);
	$aui->caption(
		right => Wx::gettext('Document Tools'),
	);

	return $self;
}





#####################################################################
# Page Management

sub show {
	my ( $self, $page, $on_close ) = @_;

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

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CLOSE( $self, $self, \&_on_close );

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

sub relocale {
	my $self = shift;
	foreach my $i ( 0 .. $self->GetPageCount - 1 ) {
		$self->SetPageText( $i, $self->GetPage($i)->gettext_label );
	}

	return;
}

sub _on_close {
	my ( $self, $event ) = @_;

	my $pos  = $event->GetSelection;
	my $type = ref $self->GetPage($pos);
	$self->RemovePage($pos);

	# De-activate in the menu
	my %menu_name = (
		'Padre::Wx::Outline'      => 'outline',
		'Padre::Wx::TodoList'     => 'todo',
		'Padre::Wx::FunctionList' => 'functions',
	);
	my %config_name = (
		'Padre::Wx::Outline'      => 'main_outline',
		'Padre::Wx::TodoList'     => 'main_todo',
		'Padre::Wx::FunctionList' => 'main_functions',
	);
	if ( exists $menu_name{$type} ) {
		$self->main->menu->view->{ $menu_name{$type} }->Check(0);
		$self->main->config->set( $config_name{$type}, 0 );
	} else {
		warn "Unknown page type: '$type'\n";
	}

	# Is this the last page?
	if ( $self->GetPageCount == 0 ) {
		$self->Hide;
		$self->aui->GetPane($self)->Hide;
	}

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
