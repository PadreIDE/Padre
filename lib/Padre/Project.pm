package Padre::Project;

# Base project functionality for Padre

use 5.008;
use strict;
use warnings;
use File::Spec      ();
use Padre::Constant ();
use Padre::Current  ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Flag to indicate this root is specifically provided by a user
	# and is not intuited.
	$self->{explicit} = !!$self->{explicit};

	# Check the root directory
	unless ( defined $self->root ) {
		Carp::croak("Did not provide a root directory");
	}
	unless ( -d $self->root ) {
		return undef;
	}

	# Check for a padre.yml file
	my $padre_yml = File::Spec->catfile(
		$self->root,
		'padre.yml',
	);
	if ( -f $padre_yml ) {
		$self->{padre_yml} = $padre_yml;
	}

	return $self;
}

### DEPRECATED
sub from_file {
	if ( $VERSION > 0.84 ) {
		warn "Deprecated Padre::Project::from_file called by " . scalar caller();
	}

	require Padre::Current;
	Padre::Current->ide->project_manager->from_file( $_[1] );
}

sub explicit {
	$_[0]->{explicit};
}

sub root {
	$_[0]->{root};
}

sub padre_yml {
	$_[0]->{padre_yml};
}





######################################################################
# Navigation Convenience Methods

sub documents {
	my $self = shift;
	my $root = $self->root;
	require Padre::Current;
	return grep { $_->project_dir eq $root } Padre::Current->main->documents;
}





######################################################################
# Configuration and Intuition

sub config {
	my $self = shift;

	# We only need our own config file if we have a padre.yml file
	unless ( defined $self->{padre_yml} ) {
		require Padre::Current;
		return Padre::Current->config;
	}

	unless ( $self->{config} ) {

		# Get the default config object
		my $config = Padre::Current->config;

		# If we have a padre.yml file create a custom config object
		if ( $self->{padre_yml} ) {
			require Padre::Config;
			require Padre::Config::Project;
			$self->{config} = Padre::Config->new(
				$config->host,
				$config->human,
				Padre::Config::Project->read(
					$self->{padre_yml},
				),
			);
		} else {
			require Padre::Config;
			$self->{config} = Padre::Config->new(
				$config->host,
				$config->human,
			);
		}
	}

	return $self->{config};
}

# Locate the "primary" file, if the project has one
sub headline {
	return undef;
}

# As above but an absolute path
sub headline_path {
	my $self     = shift;
	my $headline = $self->headline;
	return undef unless defined $headline;
	File::Spec->catfile( $self->root, $headline );
}

# Intuit the distribution version if possible
sub version {
	return undef;
}

# What is the logical name of the version control system we are using.
# Identifying the version control flavour is the only support we provide.
# Anything more details needs to be in the version control plugin.
# Returns a name or undef if no version control.
sub vcs {
	my $self = shift;
	unless ( exists $self->{vcs} ) {
		my $class = ref $self;
		$self->{vcs} = $class->_vcs( $self->root );
	}
	return $self->{vcs};
}

sub _vcs {
	my $class = shift;
	my $root  = shift;
	if ( -d File::Spec->catdir( $root, '.svn' ) ) {
		return Padre::Constant::SUBVERSION;
	}
	if ( -d File::Spec->catdir( $root, '.git' ) ) {
		return Padre::Constant::GIT;
	}
	if ( -d File::Spec->catdir( $root, '.hg' ) ) {
		return Padre::Constant::MERCURIAL;
	}
	if ( -d File::Spec->catdir( $root, '.bzr' ) ) {
		return Padre::Constant::BAZAAR;
	}
	if ( -f File::Spec->catfile( $root, 'CVS', 'Repository' ) ) {
		return Padre::Constant::CVS;
	}
	return undef;
}





######################################################################
# Process Execution

sub temp {
	$_[0]->{temp} or $_[0]->{temp} = $_[0]->_temp;
}

sub _temp {
	require Padre::Project::Temp;
	Padre::Project::Temp->new;
}

# Synchronise all content from unsaved files in a project to the
# project-specific temporary directory.
sub temp_sync {
	my $self = shift;

	# What files do we need to save
	my @changed = grep { !$_->is_new and $_->is_modified } $self->documents or return 0;

	# Save the files to the temporary directory
	my $temp  = $self->temp;
	my $root  = $temp->root;
	my $files = 0;
	foreach my $document (@changed) {
		my $relative = $document->filename_relative;
		my $tempfile = File::Spec->rel2abs( $relative, $root );
		require File::Path;
		require File::Basename;
		File::Path::mkpath( File::Basename::basedir($tempfile) );
		my $file = Padre::File->new($tempfile);
		$document->write($file) and $files++;
	}

	return $files;
}

sub launch_shell {
	my $self   = shift;
	my $config = $self->config;
	my $shell  = $config->bin_shell or return;

	if (Padre::Constant::WIN32) {
		require Win32;
		require Padre::Util::Win32;
		Win32::SetChildShowWindow( Win32::SW_SHOWNORMAL() );
		Padre::Util::Win32::ExecuteProcessAndWait(
			directory  => $self->{project},
			file       => 'cmd.exe',
			parameters => "/C $shell",
		);
		Win32::SetChildShowWindow( Win32::SW_HIDE() );

	} else {
		require File::pushd;
		my $pushd = File::pushd::pushd( $self->root );
		system $shell;
	}

	return 1;
}

# Run a command and wait
sub launch_system {
	my $self = shift;
	my $cmd  = shift;

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
		my $pushd = File::pushd::pushd( $self->root );
		system $cmd;
	}

	return 1;
}





######################################################################
# Directory Tree Integration

# A file/directory pattern to support the directory browser.
# The function takes three parameters of the full file path,
# the directory path, and the file name.
# Returns true if the file is visible.
# Returns false if the file is ignored.
# This method is used to support the functionality of the directory browser.
sub ignore_rule {
	return sub {
		if ( $_->{name} =~ /^\./ ) {
			return 0;
		}

		if (Padre::Constant::WIN32) {

			# On Windows only ignore files or directories that
			# begin or end with a dollar sign as "hidden". This is
			# mainly relevant if we are opening some project across
			# a UNC path on more recent versions of Windows.
			if ( $_->{name} =~ /^\$/ ) {
				return 0;
			}
			if ( $_->{name} =~ /\$$/ ) {
				return 0;
			}

			# Windows thumbnailing, instead of having sensibly
			# centralised storage of thumbnails, likes to put a
			# file in every single directory.
			if ( $_->{name} eq 'Thumbs.db' ) {
				return 0;
			}

			# Likewise, desktop.ini files are stupid files used
			# by windows to make a folder behave weirdly.
			# Ignore them too.
			if ( $_->{name} eq 'desktop.ini' ) {
				return 0;
			}
		}

		return 1;
	};
}

# Alternate form
sub ignore_skip {
	my $rule = [
		'(?:^|\\/)\\.',
	];

	if (Padre::Constant::WIN32) {

		# On Windows only ignore files or directories that begin or end
		# with a dollar sign as "hidden". This is mainly relevant if
		# we are opening some project across a UNC path on more recent
		# versions of Windows.
		push @$rule, "(?:^|\\/)\\\$";
		push @$rule, "\\\$\$";

		# Windows thumbnailing, instead of having sensibly centralised
		# storage of thumbnails, likes to put a file in every single directory.
		push @$rule, "(?:^|\\/)Thumbs.db\$";

		# Likewise, desktop.ini files are stupid files used by windows
		# to make a folder behave weirdly. Ignore them too.
		push @$rule, "(?:^|\\/)desktop.ini\$";
	}

	return $rule;
}

sub name {
	my $self = shift;
	my $name = ( reverse( File::Spec->splitdir( $self->root ) ) )[0];

	if ( !defined $name or $name eq '' ) { # Fallback
		$name = $self->root;
		$name =~ s/^.*[\/\\]//;
	}

	return $name;
}





######################################################################
# Padre::Cache Integration

# The detection of VERSION allows us to make this call without having
# to load modules at project destruction time if it isn't needed.
sub DESTROY {
	if ( defined $_[0]->{root} and $Padre::Cache::VERSION ) {
		Padre::Cache->release( $_[0]->{root} );
	}
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
