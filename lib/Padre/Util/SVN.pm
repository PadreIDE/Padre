package Padre::Util::SVN;

# Isolate the subversion-specific functions, because in some situations
# we need them early in the load process and we want to avoid loading
# a whole ton of dependencies.

use 5.008005;
use strict;
use warnings;

my $PADRE = undef;

# TODO: A much better variant would be a constant set by svn.
sub padre_revision {
	unless ( $PADRE ) {
		if ( $0 =~ /padre$/ ) {
			my $dir = $0;
			$dir =~ s/padre$//;
			my $revision = directory_revision($dir);
			if ( -d "$dir.svn" ) {
				$PADRE = 'r' . $revision;
			}
		}
	}
	return $PADRE;
}

# This is pretty hacky
sub directory_revision {
	my $dir = shift;

	# Find the entries file
	my $entries = File::Spec->catfile( $dir, '.svn', 'entries' );
	return unless -f $entries;

	# Find the headline revision
	local $/ = undef;
	open( my $fh, "<", $entries ) or return;
	my $buffer = <$fh>;
	close $fh;

	# Find the first number after the first occurance of "dir".
	unless ( $buffer =~ /\bdir\b\s+(\d+)/m ) {
		return;
	}

	# Quote this to prevent certain aliasing bugs
	return "$1";
}

1;
