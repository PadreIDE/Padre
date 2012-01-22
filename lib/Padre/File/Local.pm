package Padre::File::Local;

use 5.008;
use strict;
use warnings;
use File::Basename  ();
use File::Spec      ();
use Padre::Constant ();
use Padre::File     ();

our $VERSION = '0.94';
our @ISA     = 'Padre::File';

sub _reformat_filename {
	my $self = shift;

	if (Padre::Constant::WIN32) {

		# Fixing the case of the filename on Win32.
		require Win32;
		$self->{filename} = Win32::GetLongPathName( $self->{filename} )
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

	$self->{filename} = File::Spec->rel2abs( $self->{filename} )
		unless File::Spec->file_name_is_absolute( $self->{filename} );

	$self->_reformat_filename;

	return $self;
}

sub can_clone {

	# Local files don't have connections, no need to clone objects
	return 0;
}

sub can_run {
	return 1;
}

sub can_delete {
	my $self = shift;

	# Can't delete readonly files
	return $self->readonly ? 0 : 1;
}

sub stat {
	my $self = shift;
	return CORE::stat( $self->{filename} );
}

sub size {
	my $self = shift;
	return -s $self->{filename} || 0;
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
	return ( CORE::stat( $self->{filename} ) )[8] || 0;
}

sub mtime {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[9] || 0;
}

sub ctime {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[10] || 0;
}

sub blksize {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[11] || 0;
}

sub blocks {
	my $self = shift;
	return ( CORE::stat( $self->{filename} ) )[12] || 0;
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
	return if not defined $self->{filename};

	if ( open my $fh, '<', $self->{filename} ) {
		binmode($fh);
		local $/ = undef;
		my $buffer = <$fh>;
		close $fh;
		return $buffer;
	}

	$self->{error} = $!;
	return;
}

sub write {
	my $self    = shift;
	my $content = shift;
	my $encode  = shift || ''; # undef encode = default, but undef will trigger a warning

	if ( open my $fh, ">$encode", $self->{filename} ) {
		print {$fh} $content;
		close $fh;
		return 1;
	}

	$self->{error} = $!;
	return;
}

sub basename {
	my $self = shift;
	return File::Basename::basename( $self->{filename} );
}

sub dirname {
	my $self = shift;
	return File::Basename::dirname( $self->{filename} );
}

sub splitvdir {
	my ( $v, $d, $f ) = File::Spec->splitpath( $_[0]->{filename} );
	my @d = File::Spec->splitdir($d);
	pop @d if $d[-1] eq '';
	return $v, @d;
}

sub splitall {
	my ( $v, $d, $f ) = File::Spec->splitpath( $_[0]->{filename} );
	my @d = File::Spec->splitdir($d);
	pop @d if $d[-1] eq '';
	return $v, @d, $f;
}

sub readonly {
	my $self = shift;
	return 1 if ( !-w $self->{filename} );
}

sub browse_url_join {
	my $self     = shift;
	my $server   = shift;
	my $path     = shift;
	my $filename = shift;

	return File::Spec->catfile( $server, $path, $filename );
}

sub delete {
	my $self = shift;

	return 1 if unlink $self->{filename};

	$self->{error} = $!;
}


1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
