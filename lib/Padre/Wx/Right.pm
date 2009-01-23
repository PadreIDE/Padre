package Padre::Wx::Right;

# The right-hand notebook

use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.26';
our @ISA     = 'Wx::AuiNotebook';

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the platform-sensitive style
	my $style = Wx::wxAUI_NB_SCROLL_BUTTONS
		| Wx::wxAUI_NB_TOP
		| Wx::wxBORDER_NONE;
	unless ( Padre::Util::WXGTK ) {
		# Crashes on Linux/GTK
		# Doesn't seem to work right on Win32...
		# $style = $style | Wx::wxAUI_NB_TAB_EXTERNAL_MOVE;
	}

	# Create the basic object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::wxDefaultPosition,
		Wx::Size->new(300, 350), # used when pane is floated
		$style,
	);

	# Add ourself to the window manager
	$self->aui->AddPane(
		$self,
		Wx::AuiPaneInfo->new
			->Name('right')
			->Resizable(1)
			->PaneBorder(0)
			->Movable(1)
			->CaptionVisible(1)
			->CloseButton(0)
			->DestroyOnClose(0)
			->MaximizeButton(0)
			->Floatable(1)
			->Dockable(1)
			->Position(3)
			->Right
			->Layer(3)
			->Hide
	);

	# Set the locale-aware caption
	$self->aui->caption_gettext('right' => 'Workspace View');

	return $self;
}

sub main {
	$_[0]->GetParent;
}

sub aui {
	$_[0]->GetParent->aui;
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

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
