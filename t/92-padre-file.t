#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 28;

use Padre::File;

my $file = Padre::File->new();
ok(!defined($file),'No filename');

# Padre::File::Local

our $testfile = 't/files/padre-file-test';

ok(open(my $fh,'>',$testfile),'Local: Create test file');
print $fh "foo";
close $fh;
ok(-s $testfile == 3,'Local: Check test file size');

$file = Padre::File->new($testfile);
ok(defined($file),'Local: Create Padre::File object');
ok(-s $testfile == 3,'Local: Check test file size again');
ok(ref($file) eq 'Padre::File::Local','Local: Check module');
ok($file->{protocol} eq 'local','Local: Check protocol');
my @Stat1 = stat($testfile);
my @Stat2 = $file->stat;
for (0..$#Stat1) {
	ok($Stat1[$_] eq $Stat2[$_],'Local: Check stat value '.$_);
}
# Check the most interesting functions only:
ok($file->exists,'Local: file exists');
ok($file->size == $Stat1[7],'Local: file size');
ok($file->mtime == $Stat1[9],'Local: file size');

undef $file;

# Padre::File::HTTP
$file = Padre::File->new('http://padre.perlide.org/about.html');
ok(defined($file),'HTTP: Create Padre::File object');
ok(ref($file) eq 'Padre::File::HTTP','HTTP: Check module');
ok($file->{protocol} eq 'http','HTTP: Check protocol');
ok($file->size > 0,'HTTP: file size');
ok($file->mtime >= 1253194791,'HTTP: mtime');

END {
	unlink $testfile;
}