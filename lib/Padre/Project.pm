package Padre::Project;

# Base project functionality for Padre

use 5.008;
use strict;
use warnings;
use File::Spec     ();
use File::Path     ();
use File::Basename ();
use Padre::Config  ();
use Padre::Current ();

our $VERSION = '0.58';

use Class::XSAccessor {
	getters => {
		root      => 'root',
		padre_yml => 'padre_yml',
	}
};





######################################################################
# Class Methods

sub class {
	my $class = shift;
	my $root  = shift;
	unless ( -d $root ) {

		# Carp::croak("Project directory '$root' does not exist");
		# Project root doesn't exist, this might cause problems
		# but croaking completly crashs Padre. Fix for #819
		Padre->ide->wx->main->error(
			sprintf(
				Wx::gettext(
					      'Project directory %s does not exist (any longer). '
						. 'This is fatal and will cause problems, please close or '
						. 'save-as this file unless you know what you are doing.'
				),
				$root
			)
		);
		return 'Padre::Project::Null';
	}
	if ( -f File::Spec->catfile( $root, 'Makefile.PL' ) ) {
		return 'Padre::Project::Perl';
	}
	if ( -f File::Spec->catfile( $root, 'Build.PL' ) ) {
		return 'Padre::Project::Perl';
	}
	if ( -f File::Spec->catfile( $root, 'dist.ini' ) ) {
		return 'Padre::Project::Perl';
	}
	if ( -f File::Spec->catfile( $root, 'padre.yml' ) ) {
		return 'Padre::Project';
	}
	return 'Padre::Project::Null';
}





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Check the root directory
	unless ( defined $self->root ) {
		Carp::croak("Did not provide a root directory");
	}
	unless ( -d $self->root ) {
		return undef;

		# Carp::croak( "Root directory " . $self->root . " does not exist" );
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

sub from_file {
	my $class = shift;
	my $file  = shift;

	# Split and scan
	my ( $v, $d, $f ) = File::Spec->splitpath($file);
	my @d = File::Spec->splitdir($d);
	if ( defined $d[-1] and $d[-1] eq '' ) {
		pop @d;
	}
	foreach ( reverse 0 .. $#d ) {
		my $dir = File::Spec->catdir( @d[ 0 .. $_ ] );

		# Check for Dist::Zilla support
		my $dist_ini = File::Spec->catpath( $v, $dir, 'dist.ini' );
		if ( -f $dist_ini ) {
			require Padre::Project::Perl::DZ;
			return Padre::Project::Perl::DZ->new(
				root     => File::Spec->catpath( $v, $dir, '' ),
				dist_ini => $dist_ini,
			);
		}

		# Check for Module::Build support
		my $build_pl = File::Spec->catpath( $v, $dir, 'Build.PL' );
		if ( -f $build_pl ) {
			require Padre::Project::Perl::MB;
			return Padre::Project::Perl::MB->new(
				root     => File::Spec->catpath( $v, $dir, '' ),
				build_pl => $build_pl,
			);
		}

		# Check for ExtUtils::MakeMaker and Module::Install support
		my $makefile_pl = File::Spec->catpath( $v, $dir, 'Makefile.PL' );
		if ( -f $makefile_pl ) {

			# Differentiate between Module::Install and ExtUtils::MakeMaker
			if (0) {
				require Padre::Project::Perl::MI;
				return Padre::Project::Perl::MI->new(
					root        => File::Spec->catpath( $v, $dir, '' ),
					makefile_pl => $makefile_pl,
				);
			} else {
				require Padre::Project::Perl::EUMM;
				return Padre::Project::Perl::EUMM->new(
					root        => File::Spec->catpath( $v, $dir, '' ),
					makefile_pl => $makefile_pl,
				);
			}
		}

		# Fall back to looking for null projects
		my $padre_yml = File::Spec->catpath( $v, $dir, 'padre.yml' );
		if ( -f $padre_yml ) {
			return Padre::Project->new(
				root      => File::Spec->catpath( $v, $dir, '' ),
				padre_yml => $padre_yml,
			);
		}
	}

	# This document is part of the null project
	require Padre::Project::Null;
	return Padre::Project::Null->new(
		root => File::Spec->catpath(
			$v,
			File::Spec->catdir(@d),
			'',
		),
	);
}





######################################################################
# Navigation Convenience Methods

sub documents {
	my $self = shift;
	my $root = $self->root;
	return grep { $_->project_dir eq $root } Padre::Current->main->documents;
}





######################################################################
# Configuration and Intuition

sub config {
	my $self = shift;
	unless ( $self->{config} ) {

		# Get the default config object
		my $config = Padre::Current->config;

		# If we have a padre.yml file create a custom config object
		if ( $self->{padre_yml} ) {
			require Padre::Config::Project;
			$self->{config} = Padre::Config->new(
				$config->host,
				$config->human,
				Padre::Config::Project->read(
					$self->{padre_yml},
				),
			);
		} else {
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
		my $tempdir  = File::Basename::basedir($tempfile);
		File::Path::mkpath($tempdir);
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
		} else {
			return 1;
		}
	};
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

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
