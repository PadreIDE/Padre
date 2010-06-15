package Padre::Wx::Directory::Task;

# This is a simple flexible task that fetches lists of file names
# (but does not look inside of those files)

use 5.008;
use strict;
use warnings;
use Padre::Task                ();
use Padre::Wx::Directory::Path ();

our $VERSION = '0.64';
our @ISA     = 'Padre::Task';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Default the skip rules
	$self->{skip} ||= [ ];

	# Automatic project integration
	if ( exists $self->{project} ) {
		$self->{root} = $self->{project}->root;
	}

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	require Module::Manifest;
	my $self  = shift;
	my $root  = $self->{root};
	my @queue = Padre::Wx::Directory::Path->directory;
	my @files = ();

	# Prepare the skip rules
	my $rule = Module::Manifest->new;
	$rule->parse( skip => $self->{skip} );

	# Recursively scan for files
	while ( @queue ) {
		my $parent = shift @queue;
		my @path   = $parent->path;
		my $dir    = File::Spec->catdir( $root, @path );

		# Read the file list for the directory
		opendir DIRECTORY, $dir or die "opendir($dir): $!";
		my @list = readdir DIRECTORY;
		closedir DIRECTORY;

		foreach my $file ( @list ) {
			next if $file =~ /^\.+\z/;
			if ( -f File::Spec->catfile( $dir, $file ) ) {
				my $object = Padre::Wx::Directory::Path->file(@path, $file);
				unless ( $rule->skipped($object->unix) ) {
					push @files, $object;
				}
				next;
			}
			if ( -d File::Spec->catdir( $dir, $file ) ) {
				my $object = Padre::Wx::Directory::Path->directory(@path, $file);
				unless ( $rule->skipped($object->unix) ) {
					push @files, $object;
					push @queue, $object;
				}
				next;
			}
			warn "Unknown or unsupported file type";
		}
	}

	# Sort the files for the convenience of the caller
	$self->{model} = [
		sort {
			$a->unix cmp $b->unix
		} @files
	];

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
