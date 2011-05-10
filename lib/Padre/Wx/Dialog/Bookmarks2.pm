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
	my $class = shift;
	my $main  = shift;
	my $self  = $class->new($main);

	# Focus on the set
	$self->set->SetFocus;

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

	# Hide the set section of the dialog
	$self->set->Hide;
	$self->set_label->Hide;
	$self->set_line->Hide;

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

	return 1;
}

1;
