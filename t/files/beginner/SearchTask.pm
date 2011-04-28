package Padre::Task::OpenResource::SearchTask;

use 5.008;
use strict;
use warnings;


#
# Various code snippets that used to generate false positive errors
# in the beginner error code checking
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

print "OK";

if ( my $y = 42 ) {
	print "OK";
}

if ( $x =~ /42/ ) {
	print "OK";
}


my $name = 'lang_perl5_beginner_elseif';


1;
