package Padre::DB::Migrate::Patch;

# A convenience module for writing migration patches.

use 5.008005;
use strict;
use warnings;
use DBI          ();
use DBD::SQLite  ();
use Params::Util ();

our $VERSION = '0.89';





######################################################################
# Constructor and Destructor

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Check filename
	unless ( Params::Util::_INSTANCE( $self->dbh, 'DBI::db' ) ) {
		die "Missing or invalid dbh database handle";
	}

	return $self;
}





######################################################################
# Main Methods

sub dbh {
	$_[0]->{dbh};
}

sub do {
	shift->dbh->do(@_);
}

sub selectall_arrayref {
	shift->dbh->selectall_arrayref(@_);
}

sub selectall_hashref {
	shift->dbh->selectall_hashref(@_);
}

sub selectcol_arrayref {
	shift->dbh->selectcol_arrayref(@_);
}

sub selectrow_array {
	shift->dbh->selectrow_array(@_);
}

sub selectrow_arrayref {
	shift->dbh->selectrow_arrayref(@_);
}

sub selectrow_hashref {
	shift->dbh->selectrow_hashref(@_);
}

sub pragma {
	$_[0]->do("pragma $_[1] = $_[2]") if @_ > 2;
	$_[0]->selectrow_arrayref("pragma $_[1]")->[0];
}

sub table_exists {
	$_[0]->selectrow_array(
		"select count(*) from sqlite_master where type = 'table' and name = ?",
		{}, $_[1],
	);
}

sub column_exists {
	$_[0]->table_exists( $_[1] )
		or $_[0]->selectrow_array( "select count($_[2]) from $_[1]", {} );
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

