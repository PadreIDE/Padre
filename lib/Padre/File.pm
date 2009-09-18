package Padre::File;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.46';

my %Registered_Modules;

=pod

=head1 NAME

Padre::File - Common API for file functions

=head1 DESCRIPTION

Padre::File provies a common API for file access within Padre.
It covers all the differences with non-local files by mapping every function
call to the currently used transport stream.

=head1 FUNCTIONS

=head2 REGISTER

  Padre::File::REGISTER($RegExp,$Module);

This function is NOT a OO-method, it may not be called on a Padre::File object!

A plugin could call C<Padre::File::REGISTER> to register a new protocol to
Padre::File and enable Padre to use URLs handled by this module.

Example:
	Padre::File::REGISTER('^nfs\:\/\/','Padre::Plugin::NFS');

Every file/URL opened through Padre::File which starts with nfs:// is now
handled through Padre::Plugin::NFS.
Padre::File->new() will respect this and call Padre::Plugin::NFS->new() to
handle such URLs.

Returns true on success or false on error.

REGISTERed protocols may override the internal protocols.

=cut

sub REGISTER { # RegExp,Module

	my $RegExp = shift;
	my $Module = shift;

	return 0 if !defined $RegExp;
	return 0 if $RegExp eq '';
	return 0 if !defined $Module;
	return 0 if $Module eq '';

	$Registered_Modules{$RegExp} = $Module;

	return 1;

}

=pot

=head1 METHODS

=head2 new

  my $file = Padre::File->new($File_or_URL);

The C<new> constructor lets you create a new B<Padre::File> object.

Only one parameter is accepted at the moment: The name of the file which should
be used. As soon as there are HTTP, FTP, SSH and other modules, also URLs
should be accepted.

If you know the protocol (which should be true every time you build the URL
by source), it's better to call Padre::File::Protocol->new($URL) directly
(replacing Protocol by the protocol which should be used, of course).

Returns a new B<Padre::File> or dies on error.

=cut

sub new { # URL

	my $class = shift;
	my $URL   = $_[0];

	return if ( !defined($URL) ) or ( $URL eq '' );

	my $self;

	for ( keys(%Registered_Modules) ) {
		next if $URL !~ /$_/;
		require $_;
		$self = $_->new($URL);
		return $self;
	}

	if ( $URL =~ /^file\:(.+)$/i ) {
		require Padre::File::Local;
		$self = Padre::File::Local->new($1);

	} elsif ( $URL =~ /^https?\:\/\//i ) {
		require Padre::File::HTTP;
		$self = Padre::File::HTTP->new($URL);
	} else {
		require Padre::File::Local;
		$self = Padre::File::Local->new($URL);
	}

	return $self;

}

=head2 atime

  $file->atime;

Returns the last-access time of the file.

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub atime {
	return;
}

=head2 basename

  $file->basename;

Returns the plain filename without path if a path/filename structure
exists for this module.

=cut

# Fallback if the module has no such function:
sub basename {
	return;
}

=head2 blksize

  $file->blocks;

Returns the block size of the filesystem where the file resides

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub blksize {
	return;
}

=head2 blocks

  $file->blocks;

Returns the number of blockes used by the file.

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub blocks {
	return;
}

=head2 ctime

  $file->ctime;

Returns the last-change time of the inode (not the file!).

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub ctime {
	return;
}

=head2 dev

  $file->dev;

Returns the device number of the filesystem where the file resides.

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub dev {
	return;
}

=head2 dirname

  $file->dirname;

Returns the plain path without filename if a path/filename structure
exists for this module.

=cut

# Fallback if the module has no such function:
sub dirname {
	return;
}

=head2 exists

  $file->exists;

Returns true if the file exists.
Returns false if the file doesn't exist.
Returns undef if unsure (network problem, not implemented).

=cut

# Fallback if the module has no such function:
sub exists {
	return;
}

=head2 gid

  $file->gid;

Returns the GID of the file group.

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub gid {
	return;
}

=head2 inode

  $file->inode;

Returns the inode number of the file.

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub inode {
	return;
}

=head2 mime

  $file->mime;
  $file->mime('text/plain');

Returns or sets the mime type of the file.

=cut

sub mime {
	my $self     = shift;
	my $new_mime = shift;
	defined($new_mime) and $self->{MIME} = $new_mime;
	return $self->{MIME};
}

=head2 mode

  $file->mode;

Returns the file mode (type and rights).

TODO: Add a description what exactly is returned.

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub mode {
	return;
}

=head2 mtime

  $file->mtime;

Returns the last-modification (change) time of the file.

=cut

# Fallback if the module has no such function:
sub mtime {
	return;
}

=head2 nlink

  $file->nlink;

Returns the number of hard links to the file

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub nlink {
	return;
}

=head2 rdev

  $file->rdev;

Returns the device identifier.

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub rdev {
	return;
}

=head2 read

  $file->read;

Reads the file contents and returns them.

Returns undef on error. The error message could be retrieved using the
->error method.

=cut

sub error {
	my $self = shift;
	return $self->{error};
}

=head2 size

  $file->size;

Returns the file size in bytes.

=cut

# Fallback if the module has no such function:
sub size {
	return;
}

=head2 stat

  $file->stat;

This emulates a stat call and returns the same values:


  0 dev      device number of filesystem
  1 ino      inode number
  2 mode     file mode  (type and permissions)
  3 nlink    number of (hard) links to the file
  4 uid      numeric user ID of file's owner
  5 gid      numeric group ID of file's owner
  6 rdev     the device identifier (special files only)
  7 size     total size of file, in bytes
  8 atime    last access time in seconds since the epoch
  9 mtime    last modify time in seconds since the epoch
 10 ctime    inode change time in seconds since the epoch (*)
 11 blksize  preferred block size for file system I/O
 12 blocks   actual number of blocks allocated

A module should fill as many items as possible, but if you're thinking
about using this method, always remember
  1. Usually, you need only one or two of the items, request them
     directly.
  2. Besides from local files, most of the values will not be
     accessable (resulting in undef values)
  3. On most protocols these values must be requested one-by-one
     which is very very expensive

Please always consider using the function for the value you really need
instead of using ->stat!

=cut

sub stat {
	my $self = shift;

	# If the module has a own stat function, we won't ever reach this point!

	return (
		$self->dev,
		$self->inode,
		$self->nlink,
		$self->uid,
		$self->gid,
		$self->rdev,
		$self->size,
		$self->atime,
		$self->mtime,
		$self->ctime,
		$self->blksize,
		$self->blocks
	);

}

=head2 uid

  $file->uid;

Returns the UID of the file owner.

This is usually not possible for non-local files, in these cases, undef
is returned.

=cut

# Fallback if the module has no such function:
sub uid {
	return;
}

=head2 write

  $file->write($Content);
  $file->write($Content,$Coding);

Writes the given $Content to the file, if a encoding is given and the
protocol allows the usage of encodings, it is respected.

Returns 1 on success.
Returns 0 on failure.
Returns undef if the function is not avaible on the protocol.

=cut

sub write {
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
