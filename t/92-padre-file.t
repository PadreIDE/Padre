#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 47;

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

SKIP: {
	skip 'Network testing. Failing this is no reason to stop install', 21 unless $ENV{AUTOMATED_TESTING};

	# Padre::File::HTTP
	$file = Padre::File->new('http://padre.perlide.org/about.html');
	ok( defined($file), 'HTTP: Create Padre::File object' );
	ok( ref($file) eq 'Padre::File::HTTP', 'HTTP: Check module' );
	ok( $file->{protocol} eq 'http', 'HTTP: Check protocol' );
	ok( $file->size > 0,            'HTTP: file size' );
	ok( $file->mtime >= 1253194791, 'HTTP: mtime' );
	$file->{_cached_mtime_value} = 1234567890;
	ok( $file->mtime == 1234567890, 'HTTP: mtime (cached)' );
	ok( $file->basename eq 'about.html', 'HTTP: basename' );
	ok( $file->dirname eq 'http://padre.perlide.org/', 'HTTP: dirname' );
	ok( !$file->can_run, 'HTTP: Can not run' );

	my %HTTP_Tests = (
		'http://www.google.de/'                    => [ 'http://www.google.de/',      'index.html' ],
		'http://www.perl.org/rules/the_world.html' => [ 'http://www.perl.org/rules/', 'the_world.html' ],
		'http://www.google.de/result.cgi?q=perl'   => [ 'http://www.google.de/',      'result.cgi' ],
	);

	for my $url ( keys(%HTTP_Tests) ) {
		$file = Padre::File->new($url);
		ok( defined($file), 'HTTP ' . $url . ': Create Padre::File object' );
		ok( $file->{protocol} eq 'http',               'HTTP ' . $url . ': Check protocol' );
		ok( $file->dirname    eq $HTTP_Tests{$url}->[0], 'HTTP ' . $url . ': Check dirname' );
		ok( $file->basename   eq $HTTP_Tests{$url}->[1], 'HTTP ' . $url . ': Check basename' );
	}
}

END {
	unlink $testfile;
}
