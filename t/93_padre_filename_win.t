#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Padre::File;

if ( ( $^O ne 'MSWin32' ) and ( $^O ne 'cygwin' ) ) {
	plan( tests => 1 );
	ok( 1, 'Skipped, only applies to Windows' );
	exit;
}

plan( tests => 7 );

{

	local $TODO;
	$TODO = 'Failing this is no reason to stop install' unless $ENV{AUTOMATED_TESTING};

	# The test file name is hard-coded because we need to play around with the pathname (/ or \):

	ok( open( my $fh, '>', 't/files/padre-file-test' ), 'Create test file' );
	print $fh "foo";
	close $fh;
	is( -s 't/files/padre-file-test', 3, 'Check test file size' );

	my $file = Padre::File->new('t/files/padre-file-test');
	ok( defined($file), 'Create Padre::File object' );
	ok( $file->exists,  'File exists' );

	# Now we have a Padre::File object and a testfile to play with...

	$file->{filename} = 'T/Files/Padre-File-Test';
	$file->_reformat_filename;
	is( $file->{filename}, 't\files\padre-file-test', 'Correct wrong case' );

	$file->{filename} = 'T\Files\Padre-File-Test';
	$file->_reformat_filename;
	is( $file->{filename}, 't\files\padre-file-test', 'Correct wrong case' );

	my $Crap = 'X:\foo\bar\padre-nonexistent\testfile';
	$file->{filename} = $Crap;
	$file->_reformat_filename;
	is( $file->{filename}, $Crap, 'Keep the filename on nonexistent file' );

}

END {
	unlink 't/files/padre-file-test';
}
