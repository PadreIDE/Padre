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

	return 1;
}

sub delete_all_clicked {
	my $self = shift;

	# Remove all bookmarks and reload
	Padre::DB::Bookmark->truncate;
	$self->list->Clear;

	return 1;
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
	$self->Layout;
	$self->GetSizer->Fit($self);

	return 1;
}

1;
