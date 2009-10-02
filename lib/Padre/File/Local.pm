package Padre::File::Local;

use 5.008;
use strict;
use warnings;

use Padre::File;
use File::Basename  ();
use File::Spec      ();
use Padre::Constant ();

our $VERSION = '0.47';
our @ISA     = 'Padre::File';

sub _reformat_filename {
	my $self = shift;

	if (Padre::Constant::WIN32) {

		# Fixing the case of the filename on Win32.
		require Padre::Util::Win32;
		$self->{filename} = Padre::Util::Win32::GetLongPathName( $self->{filename} )
			|| $self->{filename};
	}

	# Convert the filename to correct format. On Windows C:\dir\file.pl and C:/dir/file.pl are the same
	# file but have different names.
	my $New_Filename = File::Spec->catfile(

		# Handle UNC paths on win32
		Padre::Constant::WIN32
			and $self->{filename} =~ m{^\\\\}
		? File::Spec->splitpath( File::Basename::dirname( $self->{filename} ) )
		: File::Spec->splitdir( File::Basename::dirname( $self->{filename} ) ),
		File::Basename::basename( $self->{filename} )
	);

	if ( defined($New_Filename) and ( length($New_Filename) > 0 ) ) {
		$self->{filename} = $New_Filename;
	}
}

sub new {
	my $class = shift;
	my $self = bless { filename => $_[0] }, $class;
	$self->{protocol} = 'local'; # Should not be overridden

	$self->_reformat_filename;

	return $self;
}

sub stat {
	my $self = shift;
	return CORE::stat( $self->{filename} );
}

sub size {
	my $self = shift;
	return -s $self->{filename};
}

sub dev {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[0];
}

sub inode {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[0];
}

sub mode {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[2];
}

sub nlink {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[3];
}

sub uid {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[4];
}

sub gid {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[5];
}

sub rdev {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[6];
}

sub atime {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[8];
}

sub mtime {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[9];
}

sub ctime {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[10];
}

sub blksize {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[11];
}

sub blocks {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[12];
}

sub exists {
	my $self = shift;
	return -e $self->{filename};
}

sub read {
	my $self = shift;

	# The return value should be the file content, so returning
	# undef is better than nothing (in this situation) if there
	# is no filename
	return undef if ! defined($self->{filename});

	my $fh;
	if ( !open $fh, '<', $self->{filename} ) {
		$self->{error} = $!;
		return;
	}
	binmode($fh);
	local $/ = undef;
	return <$fh>;
}

sub write {
	my $self    = shift;
	my $content = shift;
	my $encode  = shift || ''; # undef encode = default, but undef will trigger a warning

	my $fh;
	if ( !open $fh, ">$encode", $self->{filename} ) {
		$self->{error} = $!;
		return 0;
	}
	print {$fh} $content;
	close $fh;

	return 1;
}

sub basename {
	my $self = shift;
	return File::Basename::basename( $self->{filename} );
}

sub dirname {
	my $self = shift;
	return File::Basename::dirname( $self->{filename} );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
