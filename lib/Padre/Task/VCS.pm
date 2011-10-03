package Padre::Task::VCS;

use 5.008005;
use strict;
use warnings;
use Padre::Task ();
use Padre::Util ();
use File::Temp  ();
use Padre::Logger;

our $VERSION = '0.91';
our @ISA     = 'Padre::Task';

######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Just convert the document to text for now.
	# Later, we'll suck in more data from the project and
	# other related documents to do VCS operations more awesomely.
	unless ( Params::Util::_INSTANCE( $self->{document}, 'Padre::Document' ) ) {
		die "Failed to provide a document to the VCS task\n";
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

	# Pull things off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my $vcs         = delete $self->{vcs}         if $self->{vcs};
	my $project_dir = delete $self->{project_dir} if $self->{project_dir};

	# We only support Subversion at the moment
	#TODO support GIT!
	return unless $vcs eq Padre::Constant::SUBVERSION;

	# Create a temporary file for standard output redirection
	my $out = File::Temp->new( UNLINK => 1 );
	$out->close;

	# Create a temporary file for standard error redirection
	my $err = File::Temp->new( UNLINK => 1 );
	$err->close;

	# Find the svn command line
	my $svn = File::Which::which('svn') or return;

	# Handle spaces in git executable path under win32
	$svn = qq{"$svn"} if Padre::Constant::WIN32;

	# 'git --no-pager show' command
	my @cmd = (
		$svn,
		'--verbose',
		'status',
		'1>' . $out->filename,
		'2>' . $err->filename,
	);

	# We need shell redirection (list context does not give that)
	# Run command in directory
	Padre::Util::run_in_directory( join( ' ', @cmd ), $project_dir );

	# Slurp git command standard input and output
	my $stdout = Padre::Util::slurp $out->filename;
	my $stderr = Padre::Util::slurp $err->filename;

	$self->{model} = [];
	if ($stdout) {
		my $output = $$stdout;
		my @lines = split /\n/, $output;
		for my $line (@lines) {
			if ( $line =~ /^(.)\s+(\d+)\s+(\d+)\s+(\w+)\s+(.+?)$/ ) {
				my $rec = {
					status  => $1,
					latest  => $2,
					current => $3,
					author  => $4,
					file    => $5,
				};
				push @{ $self->{model} }, $rec;
			}
		}
	}

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
