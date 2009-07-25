package Padre::Wx::Notebook;

use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();

our $VERSION = '0.41';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::AuiNotebook
};

######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		$main,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxAUI_NB_TOP | Wx::wxBORDER_NONE | Wx::wxAUI_NB_SCROLL_BUTTONS | Wx::wxAUI_NB_TAB_MOVE
			| Wx::wxAUI_NB_CLOSE_ON_ACTIVE_TAB | Wx::wxAUI_NB_WINDOWLIST_BUTTON
	);

	# Add ourself to the main window
	$main->aui->AddPane(
		$self,
		Padre::Wx->aui_pane_info(
			Name           => 'notebook',
			Resizable      => 1,
			PaneBorder     => 0,
			Movable        => 1,
			CaptionVisible => 0,
			CloseButton    => 0,
			MaximizeButton => 0,
			Floatable      => 1,
			Dockable       => 1,
			Layer          => 1,
		)->CenterPane,
	);
	$main->aui->caption(
		'notebook' => Wx::gettext('Files'),
	);

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CHANGED(
		$self, $self,
		sub {
			$_[0]->on_auinotebook_page_changed( $_[1] );
		},
	);

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CLOSE(
		$main, $self,
		sub {
			shift->on_close(@_);
		},
	);

	return $self;
}

######################################################################
# Main Methods

# Search for and display the page for a specified file name.
# Returns true if found and displayed, false otherwise.
sub show_file {
	my $self = shift;
	my $file = shift or return;
	foreach my $i ( 0 .. $self->GetPageCount - 1 ) {
		my $editor   = $self->GetPage($i)  or next;
		my $document = $editor->{Document} or next;
		my $filename = $document->filename;
		if ( defined $filename and $file eq $filename ) {
			$self->SetSelection($i);
			return 1;
		}
	}
	return;
}

######################################################################
# Event Handlers

sub on_auinotebook_page_changed {
	my $self   = shift;
	my $main   = $self->main;
	my $editor = $self->current->editor;
	if ($editor) {
		my $history = $main->{page_history};
		my $current = Scalar::Util::refaddr($editor);
		@$history = grep { $_ != $current } @$history;
		push @$history, $current;

		# Update indentation in case auto-update is on
		# TODO: Violates encapsulation
		$editor->{Document}->set_indentation_style;

		# make sure the outline is refreshed for the new doc
		# TODO: Violates encapsulation
		if ( $main->has_outline ) {
			$main->outline->clear;
			$main->outline->force_next(1);
		}
	}
	$main->refresh;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
