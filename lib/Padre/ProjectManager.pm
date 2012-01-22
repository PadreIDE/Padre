package Padre::ProjectManager;

# Prototype for a full project manager abstraction to track projects open
# in Padre and provide a variety of utility functions.

use 5.008;
use strict;
use warnings;
use File::Spec     ();
use Scalar::Util   ();
use Padre::Project ();

our $VERSION = '0.94';





######################################################################
# Constructors

sub new {
	my $class = shift;
	my $self  = bless {

		# For now just store projects in the HASH directly
	}, $class;
	return $self;
}

sub project {
	my $self = shift;
	my $root = shift;

	# Is this root an existing project?
	if ( defined $self->{$root} ) {
		return $self->{$root};
	}

	# Check for Dist::Zilla support
	my $dist_ini = File::Spec->catfile( $root, 'dist.ini' );
	if ( -f $dist_ini ) {
		require Padre::Project::Perl::DZ;
		return $self->{$root} = Padre::Project::Perl::DZ->new(
			root     => $root,
			dist_ini => $dist_ini,
		);
	}

	# Check for Module::Build support
	my $build_pl = File::Spec->catfile( $root, 'Build.PL' );
	if ( -f $build_pl ) {
		require Padre::Project::Perl::MB;
		return $self->{$root} = Padre::Project::Perl::MB->new(
			root     => $root,
			build_pl => $build_pl,
		);
	}

	# Check for ExtUtils::MakeMaker and Module::Install support
	my $makefile_pl = File::Spec->catfile( $root, 'Makefile.PL' );
	if ( -f $makefile_pl ) {

		# Differentiate between Module::Install and ExtUtils::MakeMaker
		if (0) {
			require Padre::Project::Perl::MI;
			return $self->{$root} = Padre::Project::Perl::MI->new(
				root        => $root,
				makefile_pl => $makefile_pl,
			);
		} else {
			require Padre::Project::Perl::EUMM;
			return $self->{$root} = Padre::Project::Perl::EUMM->new(
				root        => $root,
				makefile_pl => $makefile_pl,
			);
		}
	}

	# Check for an explicit vanilla project
	my $padre_yml = File::Spec->catfile( $root, 'padre.yml' );
	if ( -f $padre_yml ) {
		return $self->{$root} = Padre::Project->new(
			root      => $root,
			padre_yml => $padre_yml,
		);
	}

	# Intuit a vanilla project based on a version control system
	# checkout (that use a directory to indicate the root).
	foreach my $vcs ( '.svn', '.git', '.hg', '.bzr' ) {
		my $vcs_dir = File::Spec->catfile( $root, $vcs );
		if ( -d $vcs_dir ) {
			my $vcs_plugin = {
				'.svn' => 'SVN',
				'.git' => 'Git',
				'.hg'  => 'Mercurial',
				'.bzr' => 'Bazaar',
			}->{$vcs};
			return $self->{$root} = Padre::Project->new(
				root => $root,
				vcs  => $vcs_plugin,
			);
		}
	}

	# Intuit a vanilla project based on a CVS version control directory.
	my $cvs_file = File::Spec->catfile( $root, 'CVS', 'Repository' );
	if ( -f $cvs_file ) {
		return $self->{$root} = Padre::Project->new(
			root => $root,
			vcs  => 'CVS',
		);
	}

	# No idea what this is, nothing probably
	require Padre::Project::Null;
	return $self->{$root} = Padre::Project::Null->new(
		root => $root,
		vcs  => undef,
	);
}

sub from_file {
	my $self = shift;
	my $file = shift;

	# Split and scan
	my ( $v, $d, $f ) = File::Spec->splitpath($file);
	my @d = File::Spec->splitdir($d);
	if ( defined $d[-1] and $d[-1] eq '' ) {
		pop @d;
	}

	# Is the file inside a project we have loaded already.
	# This should save a ton of filesystem calls when opening files.
	foreach my $root ( sort keys %$self ) {
		my $project = $self->{$root} or next;

		# Skip baseline projects without a padre.yml file as we
		# can't be confident enough that they are actually correct.
		if ( Scalar::Util::blessed($project) eq 'Padre::Project' ) {
			next unless $project->padre_yml;
		}

		# Split into parts (check volume before we bother to split dir)
		my ( $pv, $pd, $pf ) = File::Spec->splitpath( $root, 1 );
		if ( defined $v and defined $pv and $v ne $pv ) {
			next;
		}
		my @pd = File::Spec->splitdir($pd);
		if ( defined $pd[-1] and $pd[-1] eq '' ) {
			pop @pd;
		}
		foreach my $n ( 0 .. $#pd ) {
			last unless defined $d[$n];
			last unless $d[$n] eq $pd[$n];
			next unless $n == $#pd;

			# Found a match, return the cached project
			return $project;
		}
	}

	foreach my $n ( reverse 0 .. $#d ) {
		my $dir = File::Spec->catdir( @d[ 0 .. $n ] );
		my $root = File::Spec->catpath( $v, $dir, '' );

		# Check for Dist::Zilla support
		my $dist_ini = File::Spec->catfile( $root, 'dist.ini' );
		if ( -f $dist_ini ) {
			require Padre::Project::Perl::DZ;
			return $self->{$root} = Padre::Project::Perl::DZ->new(
				root     => $root,
				dist_ini => $dist_ini,
			);
		}

		# Check for Module::Build support
		my $build_pl = File::Spec->catfile( $root, 'Build.PL' );
		if ( -f $build_pl ) {
			require Padre::Project::Perl::MB;
			return $self->{$root} = Padre::Project::Perl::MB->new(
				root     => $root,
				build_pl => $build_pl,
			);
		}

		# Check for ExtUtils::MakeMaker and Module::Install support
		my $makefile_pl = File::Spec->catfile( $root, 'Makefile.PL' );
		if ( -f $makefile_pl ) {

			# Differentiate between Module::Install and ExtUtils::MakeMaker
			if (0) {
				require Padre::Project::Perl::MI;
				return $self->{$root} = Padre::Project::Perl::MI->new(
					root        => $root,
					makefile_pl => $makefile_pl,
				);
			} else {
				require Padre::Project::Perl::EUMM;
				return $self->{$root} = Padre::Project::Perl::EUMM->new(
					root        => $root,
					makefile_pl => $makefile_pl,
				);
			}
		}

		# Check for an explicit vanilla project
		my $padre_yml = File::Spec->catfile( $root, 'padre.yml' );
		if ( -f $padre_yml ) {
			return $self->{$root} = Padre::Project->new(
				root      => $root,
				padre_yml => $padre_yml,
			);
		}

		# Intuit a vanilla project based on a git, mercurial or Bazaar
		# checkout (that use a single directory to indicate the root).
		foreach my $vcs ( '.git', '.hg', '.bzr' ) {
			my $vcs_dir = File::Spec->catdir( $root, $vcs );
			if ( -d $vcs_dir ) {
				my $vcs_plugin = {
					'.git' => 'Git',
					'.hg'  => 'Mercurial',
					'.bzr' => 'Bazaar',
				}->{$vcs};
				return $self->{$root} = Padre::Project->new(
					root => $root,
					vcs  => $vcs_plugin,
				);
			}
		}

		# Intuit a vanilla project based on a Subversion checkout
		my $svn_dir = File::Spec->catdir( $root, '.svn' );
		if ( -d $svn_dir ) {

			# This must be the top-most .svn directory
			if ($n) {

				# We aren't at the top-most directory in the volume
				my $updir = File::Spec->catdir( @d[ 0 .. $n - 1 ] );
				my $svn_updir = File::Spec->catpath( $v, $updir, '.svn' );
				unless ( -d $svn_dir ) {
					return $self->{$root} = Padre::Project->new(
						root => $root,
						vcs  => 'SVN',
					);
				}
			}
		}

		# Intuit a vanilla project based on a CVS checkout
		my $cvs_dir = File::Spec->catfile( $root, 'CVS', 'Repository' );
		if ( -f $cvs_dir ) {

			# This must be the top-most CVS directory
			if ($n) {

				# We aren't at the top-most directory in the volume
				my $updir     = File::Spec->catdir( @d[ 0 .. $n - 1 ] );
				my $cvs_updir = File::Spec->catpath(
					$v,
					File::Spec->catdir( $updir, 'CVS' ),
					'Repository',
				);
				unless ( -f $cvs_dir ) {
					return $self->{$root} = Padre::Project->new(
						root => $root,
						vcs  => 'CVS',
					);
				}
			}
		}

	}

	# This document is part of the null project
	require Padre::Project::Null;
	return Padre::Project::Null->new(
		root => File::Spec->catpath( $v, File::Spec->catdir(@d), '' ),
		vcs  => undef,
	);
}

sub from_document {
	my $self     = shift;
	my $document = shift;

	die "CODE INCOMPLETE";
}





######################################################################
# General Methods

sub project_exists {
	defined $_[0]->{ $_[1] };
}

sub projects {
	my $self = shift;
	return map { $self->{$_} } sort keys %$self;
}

sub roots {
	my $self  = shift;
	my @roots = sort keys %$self;
	return @roots;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
