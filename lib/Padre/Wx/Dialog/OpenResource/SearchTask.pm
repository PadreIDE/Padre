package Padre::Wx::Dialog::OpenResource::SearchTask;

use strict;
use warnings;
use base 'Padre::Task';
use Scalar::Util    ();
use Padre::Constant ();

our $VERSION        = '0.42';
our $thread_running = 0;

# accessors
use Class::XSAccessor accessors => {
	_directory                => '_directory',                # searched directory
	_matched_files            => '_matched_files',            # matched files list
	_skip_vcs_files           => '_skip_vcs_files',           # Skip VCS files menu item
	_skip_using_manifest_skip => '_skip_using_manifest_skip', # Skip using MANIFEST.SKIP menu item
};

#
# This is run in the main thread before being handed
# off to a worker (background) thread. The Wx GUI can be
# polled for information here.
#
sub prepare {
	my ($self) = @_;

	# move the document to the main-thread-only storage
	my $mto = $self->{main_thread_only} ||= {};
	$mto->{dialog} = $self->{dialog}
		if defined $self->{dialog};
	delete $self->{dialog};

	$self->_directory( $self->{directory} );
	$self->_skip_vcs_files( $self->{skip_vcs_files} );
	$self->_skip_using_manifest_skip( $self->{skip_using_manifest_skip} );

	# assign a place in the work queue
	if ($thread_running) {

		# single thread instance at a time please. aborting...
		return "break";
	}
	$thread_running = 1;
	return 1;
}

#
# Task thread subroutine
#
sub run {
	my $self = shift;

	# search and ignore rc folders (CVS,.svn,.git) if the user wants
	require File::Find::Rule;
	my $rule = File::Find::Rule->new;
	if ( $self->_skip_vcs_files ) {
		$rule->or(
			$rule->new->directory->name( 'CVS', '.svn', '.git', 'blib' )->prune->discard,
			$rule->new
		);
	}
	$rule->file;

	if ( $self->_skip_using_manifest_skip ) {
		my $manifest_skip_file = File::Spec->catfile( $self->_directory, 'MANIFEST.SKIP' );
		if ( -e $manifest_skip_file ) {
			use ExtUtils::Manifest qw(maniskip);
			my $skip_check = maniskip($manifest_skip_file);
			my $skip_files = sub {
				my ( $shortname, $path, $fullname ) = @_;
				return not $skip_check->($fullname);
			};
			$rule->exec( \&$skip_files );
		}
	}

	# Generate a sorted file-list based on filename
	my @matched_files =
		sort { File::Basename::fileparse($a) cmp File::Basename::fileparse($b) } $rule->in( $self->_directory );
	$self->_matched_files( \@matched_files );

	return 1;
}

#
# This is run in the main thread after the task is done.
# It can update the GUI and do cleanup.
#
sub finish {
	my ( $self, $main ) = @_;

	my $dialog = $self->{main_thread_only}->{dialog};
	$dialog->_matched_files( $self->_matched_files );
	$dialog->_status_text->SetLabel( Wx::gettext("Finished Searching") );
	$dialog->_update_matches_list_box;

	# finished here
	$thread_running = 0;

	return 1;
}

1;

__END__

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 C<< <ahmad.zawawi at gmail.com> >>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.
