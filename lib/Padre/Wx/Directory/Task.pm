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

	# Automatic project integration
	if ( exists $self->{project} ) {
		$self->{root} = $self->{project}->root;
		$self->{skip} = $self->{project}->ignore_skip;
		delete $self->{project};
	}

	# Property defaults
	unless ( defined $self->{skip} ) {
		$self->{skip} = [ ];
	}
	unless ( defined $self->{recursive} ) {
		$self->{recursive} = 1;
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
				next if $rule->skipped($object->unix);
				push @files, $object;

			} elsif ( -d File::Spec->catdir( $dir, $file ) ) {
				my $object = Padre::Wx::Directory::Path->directory(@path, $file);
				next if $rule->skipped($object->unix);
				push @files, $object;

				# Continue down within it?
				next unless $self->{recursive};
				push @queue, $object;

			} else {
				warn "Unknown or unsupported file type";
			}
		}
	}

	# Case insensitive Schwartzian sort so the caller doesn't have to
	# do the sort while blocking.
	$self->{model} = [
		sort { $a->compare($b) } @files
	];

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
