package Padre::Wx::Dialog::Bookmarks2;

use 5.008;
use strict;
use warnings;
use Padre::DB                 ();
use Padre::Wx::FBP::Bookmarks ();

our $VERSION = '0.85';
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
	$text =~ s/\r?\n?$//;
	my $name = sprintf(
		Wx::gettext("%s line %s: %s"),
		$file, $line, $text,
	);

	# Create the bookmark dialog
	my $self = $class->new($main);

	# Prepare for display
	$self->set->SetValue($name);
	$self->set->SetFocus;
	$self->set->Show;
	$self->set_label->Show;
	$self->set_line->Show;
	$self->Fit;

	# Show the dialog
	$self->refresh;
	if ( $self->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}

	return 1;
	die "CODE INCOMPLETE";
}

sub run_goto {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->new($main);

	# Show the dialog
	$self->refresh;
	if ( $self->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}

	return 1;
	die "CODE INCOMPLETE";
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

	if ( @$names ) {
		$self->list->Clear;
		foreach my $name ( @$names ) {
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
		if ( $self->list->GetSelection == Wx::wxNOT_FOUND ) {
			$self->ok->Disable;
		} else {
			$self->ok->Enable;
		}
	}

	# The Delete button should only be enabled if a bookmark is selected.
	if ( $self->list->GetSelection == Wx::wxNOT_FOUND ) {
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

1;
