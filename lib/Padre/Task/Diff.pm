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
	$self->{project} = $document->project_dir;

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Pull the text off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my $text     = delete $self->{text};
	my $vcs      = delete $self->{vcs} if ( $self->{vcs} );
	my $filename = delete $self->{filename};

	# Compare between VCS and local buffer document
	my $data = $self->_find_vcs_diff_fast( $vcs, $filename, $text );
	unless ($data) {

		# Compare between saved and current buffer document
		$data = $self->_find_local_diff( $text, $filename );
	}
	$self->{data} = $data;

	return 1;
}


sub _find_vcs_diff {
	my $self     = shift;
	my $vcs      = shift;
	my $filename = shift;

	my $vcs_exe = $self->_find_vcs_exe( $vcs, $filename );
	if ($vcs_exe) {
		my $cmd;
		if (Padre::Constant::WIN32) {
			$cmd = qq{"$vcs_exe" diff $filename};
		} else {
			$cmd = qq{$vcs_exe diff $filename};
		}
		my $output = `$cmd`;
	} else {

		# TODO handle this!
	}
}

sub _find_vcs_exe {
	my $self     = shift;
	my $vcs      = shift;
	my $filename = shift;

	my $exe;
	if ( $vcs eq Padre::Constant::SUBVERSION ) {
		$exe = 'svn';
	} elsif ( $vcs eq Padre::Constant::GIT ) {
		$exe = 'git';
	} elsif ( $vcs eq Padre::Constant::MERCURIAL ) {
		$exe = 'hg';
	} elsif ( $vcs eq Padre::Constant::BAZAAR ) {
		$exe = 'bzr';
	} elsif ( $vcs eq Padre::Constant::CVS ) {
		$exe = 'cvs';
	} else {
		TRACE("Unsupported VCS $vcs") if DEBUG;
	}

	return File::Which::which($exe);
}

sub _find_local_diff {
	my $self     = shift;
	my $text     = shift;
	my $filename = shift;

	my $content = $filename ? Padre::Util::slurp($filename) : undef;
	my $data = [];
	if ($content) {
		my @seq1 = split /^/, $$content;
		my @seq2 = split /^/, $text;
		my @diffs = Algorithm::Diff::diff( \@seq1, \@seq2 );
		$data = \@diffs;
	}

	return $data;
}

sub _find_vcs_diff_fast {
	my $self     = shift;
	my $vcs      = shift;
	my $filename = shift;
	my $text     = shift;
	my $project  = shift;

	my $data = undef;
	if ( $vcs eq Padre::Constant::SUBVERSION ) {

		# Generate a fast diff between the editor buffer and the original
		# file in the .svn folder
		# Contributed by submersible_toaster
		my $local_cheat = File::Spec->catfile(
			File::Basename::dirname($filename),
			'.svn', 'text-base',
			File::Basename::basename($filename) . '.svn-base'
		);
		my $origin = Padre::Util::slurp $local_cheat;
		if ($origin) {
			my @origin_seq  = split /^/, $$origin;
			my @unsaved_seq = split /^/, $text;
			my @diff = Algorithm::Diff::diff( \@origin_seq, \@unsaved_seq );
			$data = \@diff;
		} else {
			TRACE("Failed to find $local_cheat\n") if DEBUG;
		}
	} elsif ( $vcs eq Padre::Constant::GIT ) {
		$data = $self->_find_git_diff( $filename, $text );
	} else {

		#TODO implement the rest of the VCS like git, mercurial
		TRACE("Unhandled $vcs") if DEBUG;
	}

	return $data;
}

sub _find_git_diff {
	my $self     = shift;
	my $filename = shift;
	my $text     = shift;

	my $data;

	require File::Temp;

	# Open a temporary file for standard output redirection
	my $out = File::Temp->new( UNLINK => 1 );
	$out->close;

	# Open a temporary file for standard error redirection
	my $err = File::Temp->new( UNLINK => 1 );
	$err->close;

	# Find the git command line
	my $git = File::Which::which('git') or return;

	# Handle spaces in git executable path under win32
	$git = qq{"$git"} if Padre::Constant::WIN32;

	my $basename = File::Basename::basename($filename);
	my $dirname  = File::Basename::dirname($filename);

	my @cmd = (
		$git,
		'--no-pager',
		'show',
		"HEAD:$basename",
		'1>' . $out->filename,
		'2>' . $err->filename,
	);

	# We need shell redirection (list context does not give that)
	my $cmd = join ' ', @cmd;

	# Make sure we execute from the correct directory
	if (Padre::Constant::WIN32) {
		require Padre::Util::Win32;
		Padre::Util::Win32::ExecuteProcessAndWait(
			directory  => $self->{project},
			file       => 'cmd.exe',
			parameters => "/C $cmd",
		);
	} else {
		require File::pushd;
		my $pushd = File::pushd::pushd( $self->{project} );
		system $cmd;
	}

	# Slurp Perl's stderr...
	my $stdout;
	if ( open my $fh, '<', $out->filename ) {
		local $/ = undef;
		$stdout = <$fh>;
		close $fh;
	} else {
		die $!;
	}

	# Slurp Perl's stderr...
	my $stderr;
	if ( open my $fh, '<', $err->filename ) {
		local $/ = undef;
		$stderr = <$fh>;
		close $fh;
	} else {
		die $!;
	}

	if ( $stderr eq '' ) {

		if ($stdout) {
			my @origin_seq  = split /^/, $stdout;
			my @unsaved_seq = split /^/, $text;
			my @diff = Algorithm::Diff::diff( \@origin_seq, \@unsaved_seq );
			$data = \@diff;
		} else {
			TRACE("Failed to git show $filename\n") if DEBUG;
		}

	} else {

		# TODO handle 'An error occurred\n';
	}

}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
