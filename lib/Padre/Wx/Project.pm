package Padre::Wx::Project;

use 5.008;
use strict;
use warnings;

my $default_dir;

# Project related widgets of Padre

use Padre::Wx  ();
use Wx::Locale qw(:default);

our $VERSION = '0.22';


sub on_new_project {
	my ($self) = @_;

	# ask for project type, name and directory
	# create directory call, Module::Starter
	# set current project
	# run
	Wx::MessageBox(
		Wx::gettext("Not implemented yet"),
		Wx::gettext("Not yet available"),
		Wx::wxOK,
		$self,
	);

	return;
}

sub on_select_project {
	my ($self) = @_;

	#Wx::MessageBox("Not implemented yet", "Not yet available", Wx::wxOK, $self);
	#return;
	# popup a window with a list of projects previously selected,
	# and a button to browse for project directory
	# there should also be way to remove a project or to move a project that would
	# probably move the whole directory structure.

	my $config = Padre->ide->config;

	my $dialog = Wx::Dialog->new( $self, -1, Wx::gettext("Select Project"), [-1, -1], [-1, -1]);

	my $box  = Wx::BoxSizer->new(  Wx::wxVERTICAL   );
	my $row1 = Wx::BoxSizer->new(  Wx::wxHORIZONTAL );
	my $row2 = Wx::BoxSizer->new(  Wx::wxHORIZONTAL );
	my $row3 = Wx::BoxSizer->new(  Wx::wxHORIZONTAL );
	my $row4 = Wx::BoxSizer->new(  Wx::wxHORIZONTAL );

	$box->Add($row1);
	$box->Add($row2);
	$box->Add($row3);
	$box->Add($row4);

	$row1->Add( Wx::StaticText->new( $dialog, -1, Wx::gettext('Select Project Name or type in new one')), 1, Wx::wxALL, 3 );

	my @projects = keys %{ $config->{projects} };
	my $choice = Wx::ComboBox->new( $dialog, -1, '', [-1, -1], [-1, -1], \@projects);
	$row2->Add( $choice, 1, Wx::wxALL, 3);

	my $dir_selector = Wx::Button->new( $dialog, -1, Wx::gettext('Select Directory'));
	$row2->Add($dir_selector, 1, Wx::wxALL, 3);

	my $path = Wx::StaticText->new( $dialog, -1, '');
	$row3->Add( $path, 1, Wx::wxALL, 3 );

	EVT_BUTTON( $dialog, $dir_selector, sub {on_pick_project_dir($path, @_) } );

	# TODO later we will have other parameters for each project,
	# eg. Perl project/PHP project and each type of project might have its own parameters
	# a Perl project for example should know if it is using Build.Pl or Makefile.PL
	# it might also need to know the version control system to use and there might be other
	# parameters. Some of these should be saved in the central config file, some might need to
	# be local in the development directory and checked in to version control.

	my $ok     = Wx::Button->new( $dialog, Wx::wxID_OK,     '');
	my $cancel = Wx::Button->new( $dialog, Wx::wxID_CANCEL, '');
	EVT_BUTTON( $dialog, $ok,     sub { $dialog->EndModal(Wx::wxID_OK)     } );
	EVT_BUTTON( $dialog, $cancel, sub { $dialog->EndModal(Wx::wxID_CANCEL) } );
	$row4->Add($cancel, 1, Wx::wxALL, 3);
	$row4->Add($ok,     1, Wx::wxALL, 3);

	$dialog->SetSizer($box);
	#$box->SetSizeHints( $self );

	if ($dialog->ShowModal == Wx::wxID_CANCEL) {
		return;
	}
	my $project = $choice->GetValue;
	my $dir = $path->GetLabel;
	if (not defined $project or $project eq '') {
		#msg
		return;
	}
	if (not defined $dir or $dir eq '' or not -d $dir) {
		#msg
		return;
	}
	if ($config->{projects}->{$project}) {
		#is changing allowed? how do we notice that it is not one of the already existing names?
	} else {
	   $config->{projects}->{$project}->{dir} = $dir;
	}

	$config->{current_project} = $project;

	return;
}

#sub get_project_name {
#    my ($choice, $self, $event) = @_;
#    my $dialog = Wx::TextEntryDialog->new( $self, "Project Name", "", '' );
#    if ($dialog->ShowModal == Wx::wxID_CANCEL) {
#        return;
#    }   
#    my $name = $dialog->GetValue;
#    $dialog->Destroy;
#    $choice->InsertItems([$name], 0);
#    return;
#}
#
sub on_pick_project_dir {
	my ($path, $self, $event) = @_;

	my $dialog = Wx::DirDialog->new( $self, Wx::gettext("Select Project Directory"), $default_dir);
	if ($dialog->ShowModal == Wx::wxID_CANCEL) {
#print "Cancel\n";
		return;
	}
	$default_dir = $dialog->GetPath;

	$path->SetLabel($default_dir);
#print "$default_dir\n";
	return;
}



sub on_test_project {
	my ($self) = @_;
	Wx::MessageBox(Wx::gettext("Not implemented yet"), Wx::gettext("Not yet available"), Wx::wxOK, $self);
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
