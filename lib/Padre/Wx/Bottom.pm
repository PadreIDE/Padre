package Padre::Wx::Bottom;

# The bottom notebook for tool views

use 5.008;
use strict;
use warnings;
use Padre::Constant       ();
use Padre::Wx             ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.65';
our @ISA     = qw{
	Padre::Wx::Role::Main
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
		Wx::Size->new( 350, 300 ), # Used when floating
		Wx::wxAUI_NB_SCROLL_BUTTONS | Wx::wxAUI_NB_TOP | Wx::wxBORDER_NONE | Wx::wxAUI_NB_CLOSE_ON_ACTIVE_TAB
	);

	# Add ourself to the window manager
	$aui->AddPane(
		$self,
		Padre::Wx->aui_pane_info(
			Name           => 'bottom',
			Resizable      => 1,
			PaneBorder     => 0,
			CloseButton    => 0,
			DestroyOnClose => 0,
			MaximizeButton => 1,
			Position       => 2,
			Layer          => 4,
			CaptionVisible => $unlock,
			Floatable      => $unlock,
			Dockable       => $unlock,
			Movable        => $unlock,
			)->Bottom->Hide,
	);
	$aui->caption(
		bottom => Wx::gettext('Output View'),
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
	$self->AddPage(
		$page,
		$page->gettext_label,
		1,
	);
	$page->Show;
	$self->Show;
	$self->aui->GetPane($self)->Show;

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CLOSE(
		$self, $self,
		sub {
			shift->on_close(@_);
		}
	);

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

# Allows for content-adaptive labels
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

# It is unscalable for the view notebooks to have to know what they might contain
# and then re-implement the show/hide logic (probably wrong).
# Instead, tunnel the close action to the tool and let the tool decide how to go
# about closing itself (which will usually be by delegating up to the main window).
sub on_close {
	my $self  = shift;
	my $event = shift;

	# Tunnel the request through to the tool if possible.
	my $position = $event->GetSelection;
	my $tool     = $self->GetPage($position);
	unless ( $tool->can('view_close') ) {

		# HACK: Crash in a controller manner for the moment.
		# Later just let this crash uncontrolably :)
		# DOUBLE HACK: Just warn, and pass through for now.
		my $class = ref $tool;
		warn "Panel tool $class does define 'view_close' method";
		return $self->_on_close($event);
	}
	$tool->view_close;
}

sub _on_close {
	my ( $self, $event ) = @_;

	my $pos  = $event->GetSelection;
	my $type = ref $self->GetPage($pos);
	$self->RemovePage($pos);

	# De-activate in the menu and in the configuration
	my %menu_name = (
		'Padre::Wx::ErrorList' => 'show_errorlist',
	);
	my %config_name = (
		'Padre::Wx::ErrorList' => 'main_errorlist',
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
