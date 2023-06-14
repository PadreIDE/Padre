package Padre::Task::VCS;

use 5.008005;
use strict;
use warnings;
use Padre::Task ();
use Padre::Util ();
use File::Temp  ();
use File::Spec  ();
use Padre::Logger;
use Try::Tiny;

our $VERSION = '1.02';
our @ISA     = 'Padre::Task';

use constant {
	VCS_STATUS => 'status',
	VCS_UPDATE => 'update',
	VCS_ADD    => 'add',
	VCS_DELETE => 'delete',
	VCS_REVERT => 'revert',
	VCS_COMMIT => 'commit',
};


######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Assert required document parameter
	unless ( Params::Util::_INSTANCE( $self->{document}, 'Padre::Document' ) ) {
		die "Failed to provide a document to the VCS task\n";
	}

	# Assert required command parameter
	unless ( defined $self->{command} ) {
		die "Failed to provide a command to the VCS task\n";
	}

	# Remove the document entirely as we do this,
	# as it won't be able to survive serialisation.
	my $document = delete $self->{document};

	# Obtain project's Version Control System (VCS)
	$self->{vcs} = $document->project->vcs;

	# Obtain document project dir
	$self->{project_dir} = $document->project_dir;

	return $self;
}



######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Create empty model
	$self->{model} = [];

	# Pull things off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	return unless $self->{command};
	my $command = delete $self->{command};
	return unless $self->{vcs};
	my $vcs = $self->{vcs};
	return unless $self->{project_dir};
	my $project_dir = delete $self->{project_dir};

	# bail out if a version control system is not currently supported
	return unless ( $vcs eq Padre::Constant::SUBVERSION or $vcs eq Padre::Constant::GIT );

	if ( $command eq VCS_STATUS ) {
		if ( $vcs eq Padre::Constant::SUBVERSION ) {
			$self->{model} = $self->_find_svn_status($project_dir);
		} elsif ( $vcs eq Padre::Constant::GIT ) {
			$self->{model} = $self->_find_git_status($project_dir);
		} else {
			die VCS_STATUS . " is not supported for $vcs\n";
		}
	} else {
		die "$command is not currently supported\n";
	}

	return 1;
}

sub _find_svn_status {
	my ( $self, $project_dir ) = @_;

	my @model = ();

	# Find the svn command line
	my $svn = File::Which::which('svn') or return \@model;

	# Handle spaces in executable path under win32
	$svn = qq{"$svn"} if Padre::Constant::WIN32;

	#Now uses run in dir
	my $svn_info_ref = Padre::Util::run_in_directory_two(
		cmd    => "$svn --no-ignore --verbose status", dir => $project_dir,
		option => '0'
	);
	my %svn_info = %{$svn_info_ref};

	if ( $svn_info{output} ) {
		for my $line ( split /^/, $svn_info{output} ) {

			# Remove newlines and an extra CR (carriage return)
			chomp($line);
			$line =~ s/\r//g;
			if ( $line =~ /^(\?|I)\s+(.+?)$/ ) {

				# Handle unversioned and ignored objects
				push @model,
					{
					status   => $1,
					revision => '',
					author   => '',
					path     => $2,
					fullpath => File::Spec->catfile( $project_dir, $2 ),
					};
			} elsif ( $line =~ /^(.)\s+\d+\s+(\d+)\s+(\w+)\s+(.+?)$/ ) {

				# Handle other cases
				push @model,
					{
					status   => $1,
					revision => $2,
					author   => $3,
					path     => $4,
					fullpath => File::Spec->catfile( $project_dir, $4 ),
					};
			} else {

				# Log the event but do not do anything drastic
				# about it
				TRACE("Cannot understand '$line'") if DEBUG;
			}
		}
	}

	return \@model;
}

sub _find_git_status {
	my ( $self, $project_dir ) = @_;

	my @model = ();

	# Find the git command line
	my $git = File::Which::which('git') or return \@model;

	# Handle spaces in executable path under win32
	$git = qq{"$git"} if Padre::Constant::WIN32;

	#Now uses run in dir
	my $git_info_ref = Padre::Util::run_in_directory_two(
		cmd    => "$git status --short", dir => $project_dir,
		option => '0'
	);
	my %git_info = %{$git_info_ref};

	if ( $git_info{output} ) {
		for my $line ( split /^/, $git_info{output} ) {
			chomp($line);
			if ( $line =~ /^(..)\s+(.+?)(?:\s\->\s(.+?))?$/ ) {

				# Handle stuff
				my $status = $1;
				my $path = defined $3 ? $3 : $2;

				$status =~ s/(^\s+)|(\s+$)//;
				$status =~ s/\?\?/?/;
				push @model,
					{
					status   => $status,
					revision => '',
					author   => '',
					path     => $path,
					fullpath => File::Spec->catfile( $project_dir, $path ),
					};
			} else {

				# Log the event but do not do anything drastic
				# about it
				TRACE("Cannot understand '$line'") if DEBUG;
			}
		}
	}

	return \@model;
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
