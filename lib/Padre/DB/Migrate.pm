package Padre::DB::Migrate;

# This is a highly modified variant of ORLite::Migrate

use 5.008005;
use strict;
use warnings;
use Carp          ();
use Class::Unload ();
use File::Spec 3.2701 ();
use File::Path 2.04   ();
use File::Basename ();
use Params::Util 0.37 ();
use DBI 1.58          ();
use DBD::SQLite 1.21  ();
use ORLite 1.28       ();

our $VERSION = '0.88';
our @ISA     = 'ORLite';

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

	# We're done with the prune setting now
	$params{prune} = 0;

	# Get the current schema version
	my $dsn     = "dbi:SQLite(AutoCommit=>1,PrintError=>0):$file";
	my $dbh     = DBI->connect($dsn);
	my $version = $dbh->selectrow_arrayref('pragma user_version')->[0];
	my $want    = $params{user_version};

	# Attempt to roll the schema version forwards
	while (1) {
		local $@;

		# Shortcut if we are already at the target version
		if ( $want and $want == $version ) {
			last;
		}

		# Attempt to load the next patch class, if it exists
		my $patch = "Padre::DB::Migrate::Patch" . ++$version;
		Params::Util::_DRIVER( $patch, 'Padre::DB::Migrate::Patch' ) or last;

		# Run the upgrade
		print STDERR "Applying schema patch $patch...\n" if $DEBUG;
		eval { $patch->new( dbh => $dbh )->upgrade; };
		die "$patch: Failed to upgrade database schema: $@" if $@;

		# Successfully upgraded the schema
		$dbh->do("pragma user_version = $version");

		# Clean up the patch namespace
		Class::Unload->unload($patch);
	}

	# We are finished with the database
	$dbh->disconnect;

	local $SIG{__WARN__} = sub {
		return if $_[0] =~ /Subroutine \w+ redefined at/;
		warn $_[0];
	};

	# Hand off to the regular constructor
	$class->SUPER::import(
		\%params,
		$DEBUG ? '-DEBUG' : ()
	);
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
