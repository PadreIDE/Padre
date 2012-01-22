package Padre::Wx::Notebook;

=pod

=head1 NAME

Padre::Wx::Notebook - Notebook that holds a set of editor objects

=head1 DESCRIPTION

B<Padre::Wx::Notebook> implements the tabbed notebook in the main window
that stores the editors for open documents in Padre.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Params::Util          ();
use Padre::Wx             ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.94';
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
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::AUI_NB_TOP | Wx::BORDER_NONE | Wx::AUI_NB_SCROLL_BUTTONS | Wx::AUI_NB_TAB_MOVE
			| Wx::AUI_NB_CLOSE_ON_ACTIVE_TAB | Wx::AUI_NB_WINDOWLIST_BUTTON
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
			)->Center,
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

sub refresh {
	my $self = shift;

	# Hand off to the refresh_notebook method for each
	# of the individual editors.
	foreach my $editor ( $self->editors ) {
		$editor->refresh_notebook;
	}

	return;
}

# Do a normal refresh on relocale, that should be enough
sub relocale {
	$_[0]->refresh;
}





######################################################################
# Main Methods

=pod

=head2 show_file

  $notebook->show_file('/home/user/path/script.pl');

The C<show_file> method takes a single parameter of a fully resolved
filesystem path, finds the notebook page containing the editor for that
file, and sets that editor to be the currently selected foreground page.

Returns true if found and displayed, or false otherwise.

=cut

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

	# Hide the Find Fast panel when this changes
	$main->show_findfast(0);

	$main->ide->plugin_manager->plugin_event('editor_changed');
}





######################################################################
# Introspection and Convenience


=pod

=head2 pageids

    my @ids = $notebook->pageids;

Return a list of all current tab ids (integers) within the notebook.

=cut

sub pageids {
	return ( 0 .. $_[0]->GetPageCount - 1 );
}

=pod

=head2 pages

    my @pages = $notebook->pages;

Return a list of all notebook tabs. Those are the real objects, not page ids,
and should be L<Padre::Wx::Editor> objects (although they are not
guarenteed to be).

=cut

sub pages {
	my $self = shift;
	return map { $self->GetPage($_) } $self->pageids;
}

=pod

=head2 editors

    my @editors = $notebook->editors;

Return a list of all current editors. Those are the real objects, not page ids,
and are guarenteed to be L<Padre::Wx::Editor> objects.

Note: for now, this has the same meaning as the C<pages> method, but this will
change once we get specialised non-text entry tabs.

=cut

sub editors {
	return grep {
		Params::Util::_INSTANCE($_, 'Padre::Wx::Editor')
	} $_[0]->pages;
}

=pod

=head2 documents

    my @document = $notebook->documents;

Return a list of all current documents, in the specific order
they are open in the notepad.

=cut

sub documents {
	return map { $_->{Document} } $_[0]->editors;
}

=pod

=head2 prefix

The C<prefix> method scans the list of all local documents, and finds the
common root directory for all of them.

=cut

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
	my $self   = shift;
	my $label  = shift;
	my @labels = $self->labels;
	my ($id)   = grep { $label eq $labels[$_][0] } 0 .. $#labels;
	return $id;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
