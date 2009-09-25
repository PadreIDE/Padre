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
		$self->{Filename} = Padre::Util::Win32::GetLongPathName( $self->{Filename} )
			|| $self->{Filename};
	}

	# Convert the filename to correct format. On Windows C:\dir\file.pl and C:/dir/file.pl are the same
	# file but have different names.
	my $New_Filename = File::Spec->catfile(
		File::Spec->splitdir( File::Basename::dirname( $self->{Filename} ) ),
		File::Basename::basename( $self->{Filename} )
	);

	if ( defined($New_Filename) and ( length($New_Filename) > 0 ) ) {
		$self->{Filename} = $New_Filename;
	}
}

sub new {
	my $class = shift;
	my $self = bless { Filename => $_[0] }, $class;
	$self->{protocol} = 'local'; # Should not be overridden

	$self->_reformat_filename;

	return $self;
}

sub stat {
	my $self = shift;
	return CORE::stat( $self->{Filename} );
}

sub size {
	my $self = shift;
	return -s $self->{Filename};
}

sub dev {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[0];
}

sub inode {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[0];
}

sub mode {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[2];
}

sub nlink {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[3];
}

sub uid {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[4];
}

sub gid {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[5];
}

sub rdev {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[6];
}

sub atime {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[8];
}

sub mtime {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[9];
}

sub ctime {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[10];
}

sub blksize {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[11];
}

sub blocks {
	my $self = shift;
	return ( CORE::stat( $self->{Filename} ) )[12];
}

sub exists {
	my $self = shift;
	return -e $self->{Filename};
}

sub read {
	my $self = shift;
	my $fh;
	if ( !open $fh, '<', $self->{Filename} ) {
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
	if ( !open $fh, ">$encode", $self->{Filename} ) {
		$self->{error} = $!;
		return 0;
	}
	print {$fh} $content;
	close $fh;

	return 1;
}

sub basename {
	my $self = shift;
	return File::Basename::basename( $self->{Filename} );
}

sub dirname {
	my $self = shift;
	return File::Basename::dirname( $self->{Filename} );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
