package Padre::Wx::Dialog::DebugOptions;

use 5.008;
use strict;
use warnings;
use Padre::Search                ();
use Padre::Wx::FBP::DebugOptions ();

our $VERSION = '1.00';
our @ISA     = qw{
	Padre::Wx::FBP::DebugOptions
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->CenterOnParent;
	return $self;
}





######################################################################
# Event Handlers

######################################################################
# Event Handlers

sub browse_scripts {
	my $self    = shift;
	my $default = $self->find_script->GetValue;
	unless ($default) {
		$default = $self->config->default_projects_directory;
	}

	use File::Spec;

	my ( $volume, $directory, $file ) = File::Spec->splitpath( $default, -d $default );

	my $dialog = Wx::FileDialog->new(
		$self,
		Wx::gettext("Select Script to debug into"),
		File::Spec->catpath( $volume, $directory, '' )
	);
	my $result = $dialog->ShowModal;
	$dialog->Destroy;

	# Update the dialog
	unless ( $result == Wx::ID_CANCEL ) {
		$self->find_script->SetValue( $dialog->GetPath );
	}

	return;
}

sub browse_run_directory {
	my $self    = shift;
	my $default = $self->run_directory->GetValue;
	unless ($default) {
		$default = $self->config->default_run_directory;
	}

	use File::Spec;

	my ( $volume, $directory, $file ) = File::Spec->splitpath( $default, -d $default );

	my $dialog = Wx::DirDialog->new(
		$self,
		Wx::gettext("Select Directory to run script in"),
		File::Spec->catpath( $volume, $directory, '' )
	);
	my $result = $dialog->ShowModal;
	$dialog->Destroy;

	# Update the dialog
	unless ( $result == Wx::ID_CANCEL ) {
		$self->run_directory->SetValue( $dialog->GetPath );
	}

	return;
}


sub on_close {
	my $self  = shift;
	my $event = shift;
	$self->Hide;
	$self->main->editor_focus;
	$event->Skip(1);
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
