package Padre::Autosave;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

=head1 NAME

Padre::Autosave - auto-save and recovery mechanism for Padre

=head1 SYNOPSIS

  my $autosave = Padre:Autosave->new( db => 'path/to/database' );
  $autosave->save_file( $path, $type, $data, $timestamp ) = @_;

=head1 DESCRIPTION

=head1 The longer auto-save plan

The following is just a plan that is currently shelved as some people
on the Padre development list think this is not necessary and one
should use a real version control for this anyway.

So I leave it here for now, for future exploration.

I'd like to provide auto-save with some history and recovery service.

While I am writing this for Padre I'll make the code separate
so others can use it.

An SQLite database will be used for this but theoretically
any database could be used. Event plain file system.

Basically this will provide a versioned file system with
metadata and automatic cleanup.

Besides the content of the file we need to save some meta data:

=over

=item path to the file will be the unique identifier

=item timestamp

=item type of save (initial, auto-save, user initiated save, external)

=back

When opening a file for the first time it is saved in the database.(initial)

Every N seconds files that are not currently in "saved" situation
are auto-saved in the database making sure that they are only saved
if they differ from the previous state. (auto-save)

Evey time a file is saved it is also saved to the database. (user initiated save)
Before reloading a file we auto-save it. (auto-save)

Every time we notice that a file was changed on the disk if the user decides
to overwrite it we also save the (external) changed file.

Before auto-saving a file we make sure it has not changed since the
last auto-save.

In order to make sure the database does not get too big we setup
a cleaning mechanism that is executed once in a while.
There might be several options but for now:
1) Every entry older than N days will be deleted.


Based on the database we'll be able to provide the user recovery in
case of crash or accidental overwrite.

When opening padre we should check if there are files in the database
that the last save was B<not> a user initiated save and offer recovery.

When opening a file we should also check how is it related
to the last save in the database.

For buffers that were never saved and so have no file names
we should have some internal identifier in Padre and use that
for the auto-save till the first user initiated save.

The same mechanism will be really useful when we start
providing remote editing. Then a file is identified by
its URI ( ftp://machine/path/to/file or scp://machine/path/to/file )

  my @types = qw(initial, autosave, usersave, external);

  sub save_data {
      my ($path, $timestamp, $type, $data) = @_;
  }

=cut

sub new {
	my ( $class, %args ) = @_;
	my $self = bless \%args, $class;

	Carp::croak("No filename is given") if not $self->{dbfile};

	require ORLite;
	ORLite->import(
		{   file   => $self->{dbfile},
			create => 1,
			table  => 0,
		}
	);
	$self->setup;

	return $self;
}

sub table_exists {
	$_[0]->selectrow_array(
		"select count(*) from sqlite_master where type = 'table' and name = ?",
		{}, $_[1],
	);
}

sub setup {
	my $class = shift;

	# Create the autosave table
	$class->do(<<'END_SQL') unless $class->table_exists('autosave');
CREATE TABLE autosave (
	id          INTEGER PRIMARY KEY AUTOINCREMENT,
	path        VARCHAR(1024),
	timestamp   VARCHAR(255),
	type        VARCHAR(255),
	content     BLOB
);
CREATE INDEX file_path ON autosave (path);
END_SQL

}

sub types {
	return qw(initial autosave usersave external);
}

sub list_files {
	my $rows = $_[0]->selectall_arrayref('SELECT DISTINCT path FROM autosave');
	return map {@$_} @$rows;
}

sub save_file {
	my ( $self, $path, $type, $content ) = @_;

	Carp::croak("Missing type")         if not defined $type;
	Carp::croak("Invalid type '$type'") if not grep { $type eq $_ } $self->types;
	Carp::croak("Missing file")         if not defined $path;

	$self->do(
		'INSERT INTO autosave ( path, timestamp, type, content ) values ( ?, ?, ?, ?)',
		{}, $path, time(), $type, $content,
	);

	return;
}

sub list_revisions {
	my ( $self, $path ) = @_;

	Carp::croak("Missing file") if not defined $path;
	return $self->selectall_arrayref(
		"SELECT id, timestamp, type FROM autosave WHERE path = ? ORDER BY id",
		undef, $path
	);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
