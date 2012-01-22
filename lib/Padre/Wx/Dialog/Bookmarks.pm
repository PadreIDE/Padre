package Padre::Wx::Dialog::Bookmarks;

use 5.008;
use strict;
use warnings;
use Params::Util              ();
use Padre::DB                 ();
use Padre::Wx::FBP::Bookmarks ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::FBP::Bookmarks';





######################################################################
# Class Methods

sub run_set {
	my $class   = shift;
	my $main    = shift;
	my $current = $main->current;
	my $editor  = $current->editor or return;
	my $path    = $current->filename;
	unless ( defined $path ) {
		$main->error( Wx::gettext("Cannot set bookmark in unsaved document") );
		return;
	}

	# Determine the default name for the bookmark
	my $line   = $editor->GetCurrentLine;
	my $file   = File::Basename::basename( $path || '' );
	my ($text) = $editor->GetLine($line);
	$text = $class->clean(
		sprintf(
			Wx::gettext("%s line %s: %s"),
			$file, $line, $text,
		)
	);

	# Create the bookmark dialog
	my $self = $class->new($main);

	# Prepare for display
	$self->set->SetValue($text);
	$self->set->SetFocus;
	$self->set->Show;
	$self->set_label->Show;
	$self->set_line->Show;
	$self->Fit;

	# Show the dialog
	$self->refresh;
	if ( $self->ShowModal == Wx::ID_CANCEL ) {
		return;
	}

	# Fetch and clean the name
	my $name = $class->clean( $self->set->GetValue );
	unless ( defined Params::Util::_STRING($name) ) {
		$self->main->error( Wx::gettext('Did not provide a bookmark name') );
		return;
	}

	# Save it to the database
	SCOPE: {
		my $transaction = $self->main->lock('DB');
		Padre::DB::Bookmark->delete(
			'where name = ?', $name,
		);
		Padre::DB::Bookmark->create(
			name => $name,
			file => $path,
			line => $line,
		);
	}

	return;
}

sub run_goto {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->new($main);

	# Show the dialog
	$self->refresh;
	if ( $self->ShowModal == Wx::ID_CANCEL ) {
		return;
	}

	# Was a bookmark selected
	my $id = $self->list->GetSelection;
	if ( $id == Wx::NOT_FOUND ) {
		$self->main->error( Wx::gettext('Did not select a bookmark') );
		return;
	}

	# Can we find it in the database
	my $name     = $self->list->GetString($id);
	my @bookmark = Padre::DB::Bookmark->select(
		'where name = ?', $name,
	);
	unless (@bookmark) {

		# Deleted since the dialog was shown
		$main->error(
			sprintf(
				Wx::gettext("The bookmark '%s' no longer exists"),
				$name,
			)
		);
		return;
	}

	# Is the file already open
	my $file   = $bookmark[0]->file;
	my $line   = $bookmark[0]->line;
	my $pageid = $main->editor_of_file($file);

	# Load it if it isn't loaded
	unless ( defined $pageid ) {
		if ( -e $file ) {
			$main->setup_editor($file);
			$pageid = $main->editor_of_file($file);
		}
	}

	# Go to the relevant editor and row
	if ( defined $pageid ) {
		$main->on_nth_pane($pageid);
		my $page = $main->notebook->GetPage($pageid);
		$page->goto_line_centerize($line);
		$page->SetFocus;
	}

	return;
}





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Load the existing bookmarks
	$self->load;

	# Prepare to be shown
	$self->CenterOnParent;

	return $self;
}





######################################################################
# Event Handlers

sub delete_clicked {
	my $self = shift;
	my $list = $self->list;

	# Find the selected bookmark
	my $id       = $list->GetSelection;
	my $name     = $list->GetString($id);
	my $bookmark = Padre::DB::Bookmark->fetch_name($name);

	# Delete the bookmark
	$bookmark->delete if $bookmark;
	$list->Delete($id);

	# Update button state
	$self->refresh;
}

sub delete_all_clicked {
	my $self = shift;

	# Remove all bookmarks and reload
	Padre::DB::Bookmark->truncate;
	$self->list->Clear;

	# Update button state
	$self->refresh;
}





######################################################################
# Support Methods

sub load {
	my $self  = shift;
	my $names = Padre::DB::Bookmark->select_names;

	if (@$names) {
		$self->list->Clear;
		foreach my $name (@$names) {
			$self->list->Append( $name, $name );
		}
		$self->list->SetSelection(0);

	} else {
		$self->list->Clear;
		$self->delete->Disable;
		$self->delete_all->Disable;
	}

	# Reflow the dialog
	$self->Fit;

	return;
}

sub refresh {
	my $self = shift;

	# When in goto mode, the OK button should only be enabled if
	# there is something selected to goto.
	unless ( $self->set->IsShown ) {
		if ( $self->list->GetSelection == Wx::NOT_FOUND ) {
			$self->ok->Disable;
		} else {
			$self->ok->Enable;
		}
	}

	# The Delete button should only be enabled if a bookmark is selected.
	if ( $self->list->GetSelection == Wx::NOT_FOUND ) {
		$self->delete->Disable;
	} else {
		$self->delete->Enable;
	}

	# The Delete All button should only be enabled if there is a list
	if ( $self->list->IsEmpty ) {
		$self->delete_all->Disable;
	} else {
		$self->delete_all->Enable;
	}

	return;
}

sub clean {
	my $class = shift;
	my $name  = shift;
	$name =~ s/\s+/ /g;
	$name =~ s/^\s+//;
	$name =~ s/\s+$//;
	return $name;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
