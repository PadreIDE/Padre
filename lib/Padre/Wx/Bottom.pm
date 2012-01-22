package Padre::Wx::Bottom;

# The bottom notebook for tool views

use 5.008;
use strict;
use warnings;
use Padre::Constant       ();
use Padre::Wx             ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.94';
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
		Wx::DefaultPosition,
		Wx::Size->new( 350, 300 ), # Used when floating
		Wx::AUI_NB_SCROLL_BUTTONS | Wx::AUI_NB_TOP | Wx::BORDER_NONE | Wx::AUI_NB_CLOSE_ON_ACTIVE_TAB
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
		$page->view_label,
		1,
	);
	if ( $page->can('view_icon') ) {
		my $pos = $self->GetPageIndex($page);
		$self->SetPageBitmap( $pos, $page->view_icon );
	}
	$page->Show;
	$self->Show;
	$self->aui->GetPane($self)->Show;

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CLOSE(
		$self, $self,
		sub {
			shift->on_close(@_);
		}
	);

	if ( $page->can('view_start') ) {
		$page->view_start;
	}

	return;
}

sub hide {
	my $self     = shift;
	my $page     = shift;
	my $position = $self->GetPageIndex($page);
	if ( $position < 0 ) {

		# Not showing this
		return 1;
	}

	# Shut down the page if it is running something
	if ( $page->can('view_stop') ) {
		$page->view_stop;
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
		$self->SetPageText( $i, $self->GetPage($i)->view_label );
	}
	return;
}

sub relocale {
	my $self = shift;
	foreach my $i ( 0 .. $self->GetPageCount - 1 ) {
		my $tool = $self->GetPage($i);
		$self->SetPageText( $i, $tool->view_label );
		if ( $tool->can('relocale') ) {
			$tool->relocale;
		} else {
			my $class = ref $tool;
			warn "'$class' cannot do relocale";
		}
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
		my $class = ref $tool;
		return $self->hide($tool) if $class eq 'Wx::ListCtrl';

		warn "Panel tool $class does not define 'view_close' method";
		$self->hide($tool);
		return;
	}
	$tool->view_close;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
