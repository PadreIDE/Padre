package Padre::Task::BackupUnsaved;

use 5.008;
use strict;
use warnings;
use File::Spec      ();
use Padre::Task     ();
use Padre::Constant ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';





######################################################################
# Padre::Task Methods

# Fetch the state data at the last moment, to maximise accuracy.
sub prepare {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	my $new_count;

	# Save the list of open files
	require Padre::Current;
	$self->{changes} = {
		map { ( $_->filename || 'NEW' . ( ++$new_count ) ) => $_->text_get, }
		grep { $_->is_modified } Padre::Current->main->documents
	};

	return 1;
}

sub run {
	TRACE( $_[0] ) if DEBUG;
	my $self     = shift;
	my $filename = File::Spec->catfile(
		Padre::Constant::CONFIG_DIR,
		"unsaved_$$.storable",
	);

	# Remove the (bulky) changes from the task object so it
	# won't need to be sent back up to the main thread.
	my $changes = delete $self->{changes};

	if (%$changes) {

		# Save the content (quickly)
		require Storable;
		Storable::lock_nstore( $changes, $filename );
	} else {

		# No changed files, remove backup file
		require File::Remove;
		File::Remove::remove($filename) if -e $filename;
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
