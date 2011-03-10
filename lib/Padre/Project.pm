package Padre::Project;

# Base project functionality for Padre

use 5.008;
use strict;
use warnings;
use File::Spec      ();
use Padre::Constant ();

our $VERSION    = '0.84';
our $COMPATIBLE = '0.81';





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

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
		warn "Deprecated Padre::Util::get_project_rcs called by " . scalar caller();
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
	unless ( $self->{config} ) {

		# Get the default config object
		require Padre::Current;
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
		return 'SVN';
	}
	if ( -d File::Spec->catdir( $root, '.git' ) ) {
		return 'Git';
	}
	if ( -d File::Spec->catdir( $root, '.hg' ) ) {
		return 'Mercurial';
	}
	if ( -d File::Spec->catdir( $root, '.bzr' ) ) {
		return 'Bazaar';
	}
	if ( -f File::Spec->catfile( $root, 'CVS', 'Repository' ) ) {
		return 'CVS';
	}
	return undef;
}





######################################################################
# Process Execution Resources

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

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
