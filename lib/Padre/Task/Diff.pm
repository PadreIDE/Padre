package Padre::Task::Diff;

use 5.008005;
use strict;
use warnings;
use Params::Util    ();
use Padre::Task     ();
use Padre::Util     ();
use File::Basename  ();
use File::Spec      ();
use File::Which     ();
use File::Temp      ();
use Algorithm::Diff ();
use Padre::Logger;

our $VERSION = '0.91';
our @ISA     = 'Padre::Task';

######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Just convert the document to text for now.
	# Later, we'll suck in more data from the project and
	# other related documents to do differences calculation more awesomely.
	unless ( Params::Util::_INSTANCE( $self->{document}, 'Padre::Document' ) ) {
		die "Failed to provide a document to the diff task\n";
	}

	# Remove the document entirely as we do this,
	# as it won't be able to survive serialisation.
	my $document = delete $self->{document};

	# Obtain document full filename
	my $file = $document->{file};
	$self->{filename} = $file ? $file->filename : undef;

	# Obtain project's Version Control System (VCS)
	$self->{vcs} = $document->project->vcs;

	# Obtain document text
	$self->{text} = $document->text_get;

	# Obtain document project dir
	$self->{project_dir} = $document->project_dir;

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Pull the text off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my $text     = delete $self->{text}     if $self->{text};
	my $vcs      = delete $self->{vcs}      if ( $self->{vcs} );
	my $filename = delete $self->{filename} if $self->{filename};
	my $project_dir  = delete $self->{project_dir}  if $self->{project_dir};

	# Compare between VCS and local buffer document
	my $data = $self->_find_vcs_diff( $vcs, $project_dir, $filename, $text );
	unless ($data) {

		# Compare between saved and current buffer document
		$data = $self->_find_local_diff( $text, $filename );
	}
	$self->{data} = $data;

	return 1;
}

# Find local differences between current unsaved document and saved document
sub _find_local_diff {
	my ( $self, $text, $filename ) = @_;

	my $content = $filename ? Padre::Util::slurp($filename) : undef;
	my $data = [];
	if ($content) {
		$data = $self->_find_diffs( $$content, $text );
	}

	return $data;
}

# Find differences between VCS versioned document and current document
sub _find_vcs_diff {
	my ( $self, $vcs, $project_dir, $filename, $text ) = @_;

	return $self->_find_svn_diff( $filename, $text ) if $vcs eq Padre::Constant::SUBVERSION;
	return $self->_find_git_diff( $project_dir, $filename, $text ) if $vcs eq Padre::Constant::GIT;

	#TODO implement the rest of the VCS like mercurial, bazaar
	TRACE("Unhandled $vcs") if DEBUG;

	return;
}

# Generate a fast diff between the editor buffer and the original
# file in the .svn folder
# Contributed by submersible_toaster
sub _find_svn_diff {
	my ( $self, $filename, $text ) = @_;

	my $local_cheat = File::Spec->catfile(
		File::Basename::dirname($filename),
		'.svn', 'text-base',
		File::Basename::basename($filename) . '.svn-base'
	);
	my $origin = Padre::Util::slurp $local_cheat;
	return $origin ? $self->_find_diffs( $$origin, $text ) : undef;
}

# Find differences between git versioned document and current document
sub _find_git_diff {
	my ( $self, $project_dir, $filename, $text ) = @_;

	# Create a temporary file for standard output redirection
	my $out = File::Temp->new( UNLINK => 1 );
	$out->close;

	# Create a temporary file for standard error redirection
	my $err = File::Temp->new( UNLINK => 1 );
	$err->close;

	# Find the git command line
	my $git = File::Which::which('git') or return;

	# Handle spaces in git executable path under win32
	$git = qq{"$git"} if Padre::Constant::WIN32;

	# 'git --no-pager show' command
	my @cmd = (
		$git,
		'--no-pager',
		'show',
		"HEAD:" . File::Basename::basename($filename),
		'1>' . $out->filename,
		'2>' . $err->filename,
	);

	# We need shell redirection (list context does not give that)
	# Run command in directory
	Padre::Util::run_in_directory( join( ' ', @cmd ), $project_dir );

	# Slurp git command standard input and output
	my $stdout = Padre::Util::slurp $out->filename;
	my $stderr = Padre::Util::slurp $err->filename;

	if ( defined($stderr) and ( $$stderr eq '' ) and defined($stdout) ) {
		return $self->_find_diffs( $$stdout, $text );
	}

	return;
}

# Find differences between original text and unsaved text
sub _find_diffs {
	my ( $self, $original_text, $unsaved_text ) = @_;

	my @original_seq = split /^/, $original_text;
	my @unsaved_seq  = split /^/, $unsaved_text;
	my @diff = Algorithm::Diff::diff( \@original_seq, \@unsaved_seq );
	return \@diff;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
