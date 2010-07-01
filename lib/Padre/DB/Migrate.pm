package Padre::DB::Migrate;

# See POD at end of file for documentation

use 5.008005;
use strict;
use warnings;
use Carp ();
use File::Spec 3.2701 ();
use File::Path 2.04   ();
use File::Basename ();
use Params::Util 0.37 ();
use DBI 1.58          ();
use DBD::SQLite 1.21  ();
use ORLite 1.28       ();

use Padre::DB::Migrate::Patch ();

use vars qw{@ISA};

our $VERSION = '0.66';


BEGIN {

	@ISA = 'ORLite';
}

sub import {
	my $class = ref $_[0] || $_[0];

	# Check for debug mode
	my $DEBUG = 0;
	if ( defined Params::Util::_STRING( $_[-1] ) and $_[-1] eq '-DEBUG' ) {
		$DEBUG = 1;
		pop @_;
	}

	# Check params and apply defaults
	my %params;
	if ( defined Params::Util::_STRING( $_[1] ) ) {

		# Migrate needs at least two params
		Carp::croak("Padre::DB::Migrate must be invoked in HASH form");
	} elsif ( Params::Util::_HASH( $_[1] ) ) {
		%params = %{ $_[1] };
	} else {
		Carp::croak("Missing, empty or invalid params HASH");
	}
	$params{create} = $params{create} ? 1 : 0;
	unless (
		defined Params::Util::_STRING( $params{file} )
		and ( $params{create}
			or -f $params{file} )
		)
	{
		Carp::croak("Missing or invalid file param");
	}
	unless ( defined $params{readonly} ) {
		$params{readonly} = $params{create} ? 0 : !-w $params{file};
	}
	unless ( defined $params{tables} ) {
		$params{tables} = 1;
	}
	unless ( defined $params{package} ) {
		$params{package} = scalar caller;
	}
	unless ( Params::Util::_CLASS( $params{package} ) ) {
		Carp::croak("Missing or invalid package class");
	}
	unless ( $params{timeline} and -d $params{timeline} and -r $params{timeline} ) {
		Carp::croak("Missing or invalid timeline directory");
	}

	# We don't support readonly databases
	if ( $params{readonly} ) {
		Carp::croak("Padre::DB::Migrate does not support readonly databases");
	}

	# Get the schema version
	my $file    = File::Spec->rel2abs( $params{file} );
	my $created = !-f $params{file};
	if ($created) {

		# Create the parent directory
		my $dir = File::Basename::dirname($file);
		unless ( -d $dir ) {
			my @dirs = File::Path::mkpath( $dir, { verbose => 0 } );
			$class->prune(@dirs) if $params{prune};
		}
		$class->prune($file) if $params{prune};
	}
	my $dsn     = "dbi:SQLite:$file";
	my $dbh     = DBI->connect($dsn);
	my $version = $dbh->selectrow_arrayref('pragma user_version')->[0];
	$dbh->disconnect;

	# We're done with the prune setting now
	$params{prune} = 0;

	# Build the migration plan
	my $timeline = File::Spec->rel2abs( $params{timeline} );
	my @plan = plan( $params{timeline}, $version );

	# Execute the migration plan
	if (@plan) {

		# Does the migration plan reach the required destination
		my $destination = $version + scalar(@plan);
		if ( exists $params{user_version}
			and $destination != $params{user_version} )
		{
			die "Schema migration destination user_version mismatch (got $destination, wanted $params{user_version})";
		}

		# Load the modules needed for the migration
		require Padre::Perl;
		require File::pushd;

		# Locate the include path we need for Padre::DB::Migrate::Patch,
		# so we can force-include it and be sure they find the right one.
		my $patch_pm = 'Padre/DB/Migrate/Patch.pm';
		my $include = $INC{$patch_pm} or die("Failed to find path");
		$include = substr( $include, 0, length($include) - length($patch_pm) );

		# Execute each script
		my $perl  = Padre::Perl::wxperl();
		my $pushd = File::pushd::pushd($timeline);
		foreach my $patch (@plan) {
			my $stdin = "$file\n";
			if ($DEBUG) {
				print STDERR "Applying schema patch $patch...\n";
			}
			my $exit = system( $perl, "-I$include", $patch, $file );
			if ( $exit == -1 ) {
				Carp::croak("Migration patch $patch failed, database in unknown state");
			} elsif ( $? & 127 ) {
				Carp::croak( sprintf( "Child died with signal %d", ( $? & 127 ) ) );
			}
		}

		# Migration complete, set user_version to new state
		$dbh = DBI->connect($dsn);
		$dbh->do("pragma user_version = $destination");
		$dbh->disconnect;
	}

	# Hand off to the regular constructor
	$class->SUPER::import(
		\%params,
		$DEBUG ? '-DEBUG' : ()
	);
}





#####################################################################
# Simple Methods

sub patches {
	my $dir = shift;

	# Find all files in a directory
	local *DIR;
	opendir( DIR, $dir ) or die "opendir: $!";
	my @files = readdir(DIR) or die "readdir: $!";
	closedir(DIR) or die "closedir: $!";

	# Filter to get the patch set
	my @patches = ();
	foreach (@files) {
		next unless /^migrate-(\d+)\.pl$/;
		$patches["$1"] = $_;
	}

	return @patches;
}

sub plan {
	my $directory = shift;
	my $version   = shift;

	# Find the list of patches
	my @patches = patches($directory);

	# Assemble the plan by integer stepping forwards
	# until we run out of timeline hits.
	my @plan = ();
	while ( $patches[ ++$version ] ) {
		push @plan, $patches[$version];
	}

	return @plan;
}

1;

__END__

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

=pod

=head1 NAME

Padre::DB::Migrate - Extremely light weight SQLite-specific schema migration

=head1 SYNOPSIS

  # Build your ORM class using a patch timeline
  # stored in the shared files directory.
  use Padre::DB::Migrate {
      create       => 1,
      file         => 'sqlite.db',
      timeline     => File::Spec->catdir(
          File::ShareDir::module_dir('My::Module'), 'patches',
      ),
      user_version => 8,
  };

  # migrate-1.pl - A trivial schema patch
  #!/usr/bin/perl

  use strict;
  use DBI ();

  # Locate the SQLite database
  my $file = <STDIN>;
  chomp($file);
  unless ( -f $file and -w $file ) {
      die "SQLite file $file does not exist";
  }

  # Connect to the SQLite database
  my $dbh = DBI->connect("dbi:SQLite(RaiseError=>1):$file");
  unless ( $dbh ) {
    die "Failed to connect to $file";
  }

  $dbh->do( <<'END_SQL' );
  create table foo (
      id integer not null primary key,
      name varchar(32) not null
  )
  END_SQL

=head1 DESCRIPTION

B<THIS CODE IS EXPERIMENTAL AND SUBJECT TO CHANGE WITHOUT NOTICE>

B<YOU HAVE BEEN WARNED!>

L<SQLite> is a light weight single file SQL database that provides an
excellent platform for embedded storage of structured data.

L<ORLite> is a light weight single class Object-Relational Mapper (ORM)
system specifically designed for (and limited to only) work with SQLite.

L<Padre::DB::Migrate> is a light weight single class Database Schema
Migration enhancement for L<ORLite>.

It provides a simple implementation of schema versioning within the
SQLite database using the built-in C<user_version> pragma (which is
set to zero by default).

When setting up the ORM class, an additional C<timeline> parameter is
provided, which should point to a directory containing standalone
migration scripts.

These patch scripts are named in the form F<migrate-$version.pl>, where
C<$version> is the schema version to migrate to. A typical time line
directory will look something like the following.

  migrate-01.pl
  migrate-02.pl
  migrate-03.pl
  migrate-04.pl
  migrate-05.pl
  migrate-06.pl
  migrate-07.pl
  migrate-08.pl
  migrate-09.pl
  migrate-10.pl

L<Padre::DB::Migrate> formulates a migration plan, it will start with the
current database C<user_version>, and then step forwards looking for a
migration script that has the version C<user_version + 1>.

It will continue stepping forwards until it runs out of patches to
execute.

If L<Padre::DB::Migrate> is also invoked with a C<user_version> parameter
(to ensure the schema matches the code correctly) the plan will be
checked in advance to ensure that the migration will end at the value
specified by the C<user_version> parameter.

Because the migration plan can be calculated from any arbitrary starting
version, it is possible for any user of an older application version to
install the most current version of an application and be upgraded safely.

The recommended location to store the migration time line is a shared files
directory, locatable using one of the functions from L<File::ShareDir>.

=head1 SUPPORT

Bugs should be reported via the C<CPAN> bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=ORLite-Migrate>

For other issues, contact the author.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2009 - 2010 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
