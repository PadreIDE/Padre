#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Padre::File;

if ( $^O !~ /win/i ) {
	plan( tests => 1 );
	ok( 1, 'Skipped, only applies to Windows' );
	exit;
}

plan( tests => 6 );

# The test file name is hard-coded because we need to play around with the pathname (/ or \):

ok( open( my $fh, '>', 't/files/padre-file-test' ), 'Create test file' );
print $fh "foo";
close $fh;
ok( -s 't/files/padre-file-test' == 3, 'Check test file size' );

my $file = Padre::File->new('t/files/padre-file-test');
ok( defined($file), 'Create Padre::File object' );
ok( $file->exists,  'File exists' );

# Now we have a Padre::File object and a testfile to play with...

$file->{Filename} = 'T/Files/Padre-File-Test';
$file->_reformat_filename;
ok( ( ( $file->{Filename} eq 't/files/padre-file-test' ) or ( $file->{Filename} eq 't\files\padre-file-test' ) ),
	'Correct wrong case' );

$file->{Filename} = 'T\Files\Padre-File-Test';
$file->_reformat_filename;
ok( ( ( $file->{Filename} eq 't/files/padre-file-test' ) or ( $file->{Filename} eq 't\files\padre-file-test' ) ),
	'Correct wrong case' );

my $Crap = 'X:\foo\bar\padre-nonexistent\testfile';
$file->{Filename} = $Crap;
$file->_reformat_filename;
ok( $file->{Filename} eq $Crap, 'Keep the filename on nonexistent file' );

END {
	unlink 't/files/padre-file-test';
}
