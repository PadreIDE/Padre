package Padre::Util::SVN;

# Isolate the subversion-specific functions, because in some situations
# we need them early in the load process and we want to avoid loading
# a whole ton of dependencies.

use 5.010;
use strict;
use warnings;
use File::Spec  ();
use File::Which ();
our $VERSION = '1.00';

my $PADRE = undef;

# TODO: A much better variant would be a constant set by svn.
sub padre_revision {

	unless ($PADRE) {
		if ( $0 =~ /padre$/ ) {
			my $dir = $0;
			$dir =~ s/padre$//;

			my $svn_client_info_ref =
				Padre::Util::run_in_directory_two( cmd => 'svn info', dir => $dir, option => '0' );

			$svn_client_info_ref->{output} =~ /(?:^Revision:\s)(?<svn_version>\d+)/m;
			$PADRE = $+{svn_version};
		}

	}
	return $PADRE;
}

# This is pretty hacky
sub directory_revision {
	my $dir = shift;

	# Find the entries file
	my $entries;
	if ( !local_svn_ver() ) {
		$entries = File::Spec->catfile( $dir, '.svn', 'entries' );
	} elsif ( local_svn_ver() ) {

		#check for one dir back as svn 1.7.x
		$entries = File::Spec->catfile( $dir, '..', '.svn', 'entries' );
	}
	return unless -f $entries;

	# Find the headline revision
	local $/ = undef;
	open( my $fh, '<', $entries ) or return;
	my $buffer = <$fh>;
	close $fh;

	# Find the first number after the first occurance of "dir".
	unless ( $buffer =~ /\bdir\b\s+(\d+)/m ) {
		return;
	}

	# Quote this to prevent certain aliasing bugs
	return "$1";
}

#######
# Composed Method test_svn
#######
sub local_svn_ver {

	my $required_svn_version = '1.6.2';

	if ( File::Which::which('svn') ) {

		# test svn version
		require Padre::Util;
		my $svn_client_info_ref = Padre::Util::run_in_directory_two( cmd => 'svn --version --quiet', option => '0' );
		# p $svn_client_info_ref;
		my %svn_client_info = %{$svn_client_info_ref};

		require Sort::Versions;

		# This is so much better, now we are testing for version as well
		if ( Sort::Versions::versioncmp( $svn_client_info{output}, $required_svn_version, ) == -1 ) {
			say 'Info: you are using an svn version 1.6.2, please consider upgrading';
		}

		#return 1 if we are using svn 1.7.x
		return 1 if Sort::Versions::versioncmp( $svn_client_info{output}, '1.7' );
	}
	return 0;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
