package Padre::Task::OpenResource::SearchTask;

use 5.008;
use strict;
use warnings;


#
# Task thread subroutine
#
sub run {
	my $self = shift;

	if ( $self->_skip_using_manifest_skip ) {
		my $manifest_skip_file = File::Spec->catfile( $self->_directory, 'MANIFEST.SKIP' );
		if ( -e $manifest_skip_file ) {
			require ExtUtils::Manifest;
			ExtUtils::Manifest->import(qw(maniskip));
			my $skip_check = maniskip($manifest_skip_file);
			my $skip_files = sub {
				my ( $shortname, $path, $fullname ) = @_;
				return not $skip_check->($fullname);
			};
		}
	}

}

# if
my $x = 23;

1;
