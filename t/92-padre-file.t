#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 29;

use Padre::File;

my $file = Padre::File->new();
ok( !defined($file), 'No filename' );

# Padre::File::Local

our $testfile = 't/files/padre-file-test';

ok( open( my $fh, '>', $testfile ), 'Local: Create test file' );
print $fh "foo";
close $fh;
ok( -s $testfile == 3, 'Local: Check test file size' );

$file = Padre::File->new($testfile);
ok( defined($file),    'Local: Create Padre::File object' );

is($file->create_filename('/tmp','padre.tmp'),'/tmp/padre.tmp','Create filename (local)');

ok( -s $testfile == 3, 'Local: Check test file size again' );
ok( ref($file) eq 'Padre::File::Local', 'Local: Check module' );
ok( $file->{protocol} eq 'local', 'Local: Check protocol' );
my @Stat1 = stat($testfile);
my @Stat2 = $file->stat;
for ( 0 .. $#Stat1 ) {
	ok( $Stat1[$_] eq $Stat2[$_], 'Local: Check stat value ' . $_ );
}
ok( $file->can_run, 'Local: Can run' );

# Check the most interesting functions only:
ok( $file->exists,             'Local: file exists' );
ok( $file->size == $Stat1[7],  'Local: file size' );
ok( $file->mtime == $Stat1[9], 'Local: file size' );
ok( $file->basename eq 'padre-file-test', 'Local: basename' );

# Allow both results (for windows):
ok( ( ( $file->dirname eq 't/files' ) or ( $file->dirname eq 't\files' ) ), 'Local: dirname' );

undef $file;

END {
	unlink $testfile;
}
