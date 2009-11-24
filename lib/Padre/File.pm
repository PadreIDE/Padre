package Padre::File;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.50';

my %Registered_Modules;

=pod

=head1 NAME

Padre::File - Common API for file functions

=head1 DESCRIPTION

C<Padre::File> provides a common API for file access within Padre.
It covers all the differences with non-local files by mapping every function
call to the currently used transport stream.

=head1 METHODS

=head2 RegisterProtocol

  Padre::File->RegisterProtocol($RegExp, $Module);

Class method, may not be called on an object.

A plug-in could call C<Padre::File->RegisterProtocol> to register a new protocol to
C<Padre::File> and enable Padre to use URLs handled by this module.

Example:

  Padre::File->RegisterProtocol('^nfs\:\/\/','Padre::Plugin::NFS');

Every file/URL opened through C<Padre::File> which starts with C<nfs://> is now
handled through C<Padre::Plugin::NFS>.
C<< Padre::File->new() >> will respect this and call C<< Padre::Plugin::NFS->new() >> to
handle such URLs.

Returns true on success or false on error.

Registered protocols may override the internal protocols.

=cut

sub RegisterProtocol { # RegExp,Module
	my $RegExp = shift;
	my $Module = shift;

	return() if !defined $RegExp;
	return() if $RegExp eq '';
	return() if !defined $Module;
	return() if $Module eq '';

	$Registered_Modules{$RegExp} = $Module;

	return 1;
}

=pod

=head2 C<new>

  my $file = Padre::File->new($File_or_URL);

The C<new> constructor lets you create a new C<Padre::File> object.

Only one parameter is accepted at the moment: The name of the file which should
be used. As soon as there are HTTP, FTP, SSH and other modules, also URLs
should be accepted.

If you know the protocol (which should be true every time you build the URL
by source), it's better to call C<< Padre::File::Protocol->new($URL) >> directly
(replacing Protocol by the protocol which should be used, of course).

The module for the selected protocol should fill C<< ->{filename} >> property. This
should be used for all further references to the file as it will contain the
file name in universal correct format (for example correct the C<C:\ eq C:/> problem
on Windows).

Returns a new C<Padre::File> or dies on error.

=cut

sub new { # URL

	my $class = shift;
	my $URL   = $_[0];

	return if ( !defined($URL) ) or ( $URL eq '' );

	my $self;

	for ( keys(%Registered_Modules) ) {
		next if $URL !~ /$_/;
		require $_;
		$self = $Registered_Modules{$_}->new($URL);
		return $self;
	}

	if ( $URL =~ /^file\:(.+)$/i ) {
		require Padre::File::Local;
		$self = Padre::File::Local->new($1);

	} elsif ( $URL =~ /^https?\:\/\//i ) {
		require Padre::File::HTTP;
		$self = Padre::File::HTTP->new($URL);
	} elsif ( $URL =~ /^ftp?\:/i ) {
		require Padre::File::FTP;
		$self = Padre::File::FTP->new($URL);
	} else {
		require Padre::File::Local;
		$self = Padre::File::Local->new($URL);
	}

	$self->{Filename} = $self->{filename}; # Temporary hack

	return $self;

}

=head2 C<atime>

  $file->atime;

Returns the last-access time of the file.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub atime {}

=head2 C<basename>

  $file->basename;

Returns the plain file name without path if a path/file name structure
exists for this module.

=cut

# Fallback if the module has no such function:
# It turned out that returning everything is much better
# than returning undef for this function:
sub basename {
	my $self = shift;
	return $self->{filename};
}

=head2 C<blksize>

  $file->blksize;

Returns the block size of the file system where the file resides.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub blksize {}

=head2 C<blocks>

  $file->blocks;

Returns the number of blocks used by the file.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub blocks {}

=head2 C<can_run>

  $file->can_run;

Returns true if the protocol allows execution of files or the empty
list if it doesn't.

This is usually not possible for non-local files (which return true),
because there is no way to reproduce a save environment for running
a HTTP or FTP based file (they return false).

=cut

sub can_run {
	# If the module does not state that it could do "run",
	# we return a safe default of false.
	return();
}

=head2 C<ctime>

  $file->ctime;

Returns the last-change time of the inode (not the file!).

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub ctime {}

=head2 C<dev>

  $file->dev;

Returns the device number of the file system where the file resides.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub dev {}

=head2 C<dirname>

  $file->dirname;

Returns the plain path without file name if a path/file name structure
exists for this module.

Returns the empty list on failure or undefined behaviour for the
given protocol.

=cut

sub dirname {}

=head2 C<exists>

  $file->exists;

Returns true if the file exists.
Returns false if the file doesn't exist.
Returns the empty list if unsure (network problem, not implemented).

=cut

# Fallback if the module has no such function:
sub exists {

	my $self = shift;

	# A size indicates that the file exists:
	return 1 if $self->size;

	return;
}

=head2 C<filename>

  $file->filename;

Returns the the file name including path handled by this object.

Please remember that C<Padre::File> is able to open many URL types. This
file name may also be a URL. Please use the C<basename> and C<dirname>
methods to split it (assuming that a path exists in the current
protocol).

=cut

# Fallback if the module has no such function:
sub filename {
	my $self = shift;
	return $self->{filename};
}

=head2 C<gid>

  $file->gid;

Returns the real group ID of the file group.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub gid {}

=head2 C<inode>

  $file->inode;

Returns the inode number of the file.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub inode {}

=head2 C<mime>

  $file->mime;
  $file->mime('text/plain');

Returns or sets the MIME type of the file.

=cut

sub mime {
	my $self     = shift;
	my $new_mime = shift;
	defined($new_mime) and $self->{MIME} = $new_mime;
	return $self->{MIME};
}

=head2 C<mode>

  $file->mode;

Returns the file mode (type and rights). See also: L<perlfunc/stat>.
To get the Unixy file I<permissions> as the usual octal I<number>
(as opposed to a I<string>) use:

  use Fcntl ':mode';
  my $perms_octal = S_IMODE($file->mode);

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub mode {}

=head2 C<mtime>

  $file->mtime;

Returns the last-modification (change) time of the file.

=cut

sub mtime {}

=head2 C<nlink>

  $file->nlink;

Returns the number of hard links to the file.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub nlink {}

=head2 C<rdev>

  $file->rdev;

Returns the device identifier.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub rdev {}

=head2 C<read>

  $file->read;

Reads the file contents and returns them.

Returns the empty list on error. The error message can be retrieved using the
C<error> method.

=cut

sub error {
	my $self = shift;
	return $self->{error};
}

=head2 C<size>

  $file->size;

Returns the file size in bytes or the empty list if the
method was not implemented by the C<Padre::File> subclass.

=cut

sub size {}

=head2 C<stat>

  $file->stat;

This emulates a stat call and returns the same values:


  0 dev      device number of file system
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

=over

=item 1.

Usually, you need only one or two of the items, request them directly.

=item 2.

Besides from local files, most of the values will not be accessible (resulting
in empty lists/false returned).

=item 3.

On most protocols these values must be requested one-by-one, which is very
expensive.

=back

Please always consider using the function for the value you really need
instead of using C<stat>!

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

=head2 C<uid>

  $file->uid;

Returns the real user ID of the file owner.

This is usually not possible for non-local files, in these cases, the empty list
is returned.

=cut

sub uid {}

=head2 C<write>

  $file->write($Content);
  $file->write($Content,$Coding);

Writes the given C<$Content> to the file, if a encoding is given and the
protocol allows encoding, it is respected.

Returns 1 on success.
Returns 0 on failure.
Returns the empty list if the function is not available on the protocol.

=cut

sub write {}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
