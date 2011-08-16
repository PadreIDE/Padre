package Padre::Wx::Notebook;

use 5.008;
use strict;
use warnings;
use Params::Util          ();
use Padre::Wx             ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::AuiNotebook
};





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $main  = shift;
	my $aui   = $main->aui;

	# Create the basic object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxAUI_NB_TOP | Wx::wxBORDER_NONE | Wx::wxAUI_NB_SCROLL_BUTTONS | Wx::wxAUI_NB_TAB_MOVE
			| Wx::wxAUI_NB_CLOSE_ON_ACTIVE_TAB | Wx::wxAUI_NB_WINDOWLIST_BUTTON
	);

	# Add ourself to the main window
	$aui->AddPane(
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
	$aui->caption(
		'notebook' => Wx::gettext('Files'),
	);

	Wx::Event::EVT_AUINOTEBOOK_PAGE_CHANGED(
		$self, $self,
		sub {
			shift->on_auinotebook_page_changed(@_);
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
# GUI Methods

sub relocale {
	my $self = shift;

	# Fetch all the titles and overwrite
	foreach my $i ( 0 .. $self->GetPageCount - 1 ) {
		my $editor   = $self->GetPage($i)   or next;
		my $document = $editor->{Document}  or next;
		my $title    = $document->get_title or next;
		$self->SetPageText( $i, $title );
	}

	return;
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
	my $lock   = $main->lock( 'UPDATE', 'refresh', 'refresh_outline' );
	my $editor = $self->current->editor;

	if ($editor) {
		my $page_history = $main->{page_history};
		my $current      = Scalar::Util::refaddr($editor);
		@$page_history = grep { $_ != $current } @$page_history;
		push @$page_history, $current;
	}

	$main->ide->plugin_manager->plugin_event('editor_changed');
}





######################################################################
# Introspection and Convenience

# Find the common root path for saved files
sub prefix {
	my $self   = shift;
	my $found  = 0;
	my @prefix = ();
	foreach my $i ( 0 .. $self->GetPageCount - 1 ) {
		my $document = $self->GetPage($i)->{Document} or next;
		my $file = $document->file or next;
		$file->isa('Padre::File::Local') or next;
		unless ( $found++ ) {
			@prefix = $file->splitvdir;
			next;
		}

		# How deep do the paths match
		my @path = $file->splitvdir;
		if ( @prefix > @path ) {
			foreach ( 0 .. $#path ) {
				unless ( $prefix[$_] eq $path[$_] ) {
					@path = @path[ 0 .. $_ - 1 ];
					last;
				}
			}
			@prefix = @path;
		} else {
			foreach ( 0 .. $#prefix ) {
				unless ( $prefix[$_] eq $path[$_] ) {
					@prefix = @prefix[ 0 .. $_ - 1 ];
					last;
				}
			}
		}
	}

	return @prefix;
}

# Build a page id to label map
# returns list of ARRAY refs
#   in each ARRAY ref the first value is the label
#   the second value is the full path
sub labels {
	my $self   = shift;
	my @prefix = $self->prefix;
	my @labels = ();
	foreach my $i ( 0 .. $self->GetPageCount - 1 ) {
		my $document = $self->GetPage($i)->{Document};
		unless ($document) {
			push @labels, undef;
			next;
		}

		# "Untitled N" files
		my $file = $document->file;
		unless ($file) {
			my $title = $self->GetPageText($i);
			$title =~ s/[ *]+//;
			push @labels, [ $title, $title ];
			next;
		}

		# Show local files relative to the common prefix
		if ( $file->isa('Padre::File::Local') ) {
			my @path = $file->splitall;
			@path = @path[ scalar(@prefix) .. $#path ];
			push @labels, [ File::Spec->catfile(@path), $file->filename ];
			next;
		}

		# Show the full path to non-local files
		push @labels, [ $file->{filename}, $file->{filename} ];
	}

	return @labels;
}

sub find_pane_by_label {
	my $self  = shift;
	my $label = shift;

	my @labels = $self->labels;
	my ($id) = grep { $label eq $labels[$_][0] } 0 .. $#labels;

	return $id;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
