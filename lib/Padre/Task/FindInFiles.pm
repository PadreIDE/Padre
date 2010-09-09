package Padre::Task::FindInFiles;

use 5.008;
use strict;
use warnings;
use File::Spec  ();
use Time::HiRes ();

our $VERSION = '0.70';





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
		$self->{skip} = [];
	}

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	require Module::Manifest;
	require Padre::Wx::Directory::Path;
	my $self  = shift;
	my $root  = $self->{root};
	my @queue = Padre::Wx::Directory::Path->directory;
	my $timer = 0;
	my @files = ();

	# Prepare the search regex
	my $term = $self->{find_term};
	if ( $self->{find_regex} ) {

		# Escape non-trailing $ so they won't interpolate
		$term =~ s/\$(?!\z)/\\\$/g;
	} else {

		# Escape everything
		$term = quotemeta $term;
	}

	# Compile the search regexp
	my $regexp = eval { $self->{find_case} ? qr/$term/m : qr/$term/mi };
	return 1 if $@;

	# Prepare the skip rules
	my $rule = Module::Manifest->new;
	$rule->parse( skip => $self->{skip} );

	# Recursively scan for files
	while (@queue) {
		my $parent = shift @queue;
		my @path   = $parent->path;
		my $dir    = File::Spec->catdir( $root, @path );

		# Read the file list for the directory
		# NOTE: Silently ignore any that fail. Anything we don't have
		# permission to see inside of them will just be invisible.
		opendir DIRECTORY, $dir or next;
		my @list = readdir DIRECTORY;
		closedir DIRECTORY;

		foreach my $file (@list) {
			my $skip = 0;
			next if $file =~ /^\.+\z/;
			my $fullname = File::Spec->catdir( $dir, $file );
			my @fstat = stat($fullname);

			if ( -f _ ) {
				my $object = Padre::Wx::Directory::Path->file( @path, $file );
				next if $rule->skipped( $object->unix );

				# Parse the file
				my $line    = undef;
				my @matched = ();
				if ( open( my $fh, '<', $file->name ) ) {
					while ( defined( my $line = <$fh> ) ) {
						next unless $line =~ $regexp;
						push @matched, $line;
					}
					close $fh;
				}

				# Report the lines we matched
				if ( @matched or Time::HiRes::time() - $timer > 1 ) {
					$self->message( found => $file->name, \@matched );
				}

			} elsif ( -d _ ) {
				my $object = Padre::Wx::Directory::Path->directory( @path, $file );
				next if $rule->skipped( $object->unix );
				unshift @queue, $object;

			} else {
				warn "Unknown or unsupported file type for $fullname";
			}

		}
	}

	return 1;
}

sub found {
	require Padre::Current;
	Padre::Current->main->status( $_[1] );
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
