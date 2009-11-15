#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Padre::File;

if ( !$ENV{PADRE_NETWORK_T} ) {
	plan( tests => 1 );
	SKIP: {
		skip 'This test file requires permission to connect to the internet.', 1;
	}
	exit;
}

plan( tests => 47 );

my $file; # Define for later usage

###############################################################################
### Padre::File::FTP

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
	ok( $file->{protocol} eq 'http',                 'HTTP ' . $url . ': Check protocol' );
	ok( $file->dirname    eq $HTTP_Tests{$url}->[0], 'HTTP ' . $url . ': Check dirname' );
	ok( $file->basename   eq $HTTP_Tests{$url}->[1], 'HTTP ' . $url . ': Check basename' );
}

###############################################################################
### Padre::File::FTP

# Plain file from CPAN
$file = Padre::File->new('ftp://ftp.cpan.org/pub/CPAN/README');
ok( defined($file), 'FTP: Create Padre::File object' );
ok( ref($file) eq 'Padre::File::FTP', 'FTP: Check module' );
ok( $file->{protocol} eq 'ftp', 'FTP: Check protocol' );
ok( $file->size > 0, 'FTP: file size' );
ok( $file->basename eq 'README', 'FTP: basename' );
ok( $file->dirname eq 'ftp://ftp.cpan.org/pub/CPAN', 'FTP: dirname' );
ok( !$file->can_run, 'FTP: Can not run' );
ok( $file->exists,   'FTP: Exists' );

# Symlink
$file = Padre::File->new('ftp://ftp.kernel.org/welcome.msg');
ok( defined($file),  'FTP2: Create Padre::File object' );
ok( $file->size > 0, 'FTP2: file size' );
ok( $file->exists,   'FTP2: Exists' );

# Test some FTP servers
for my $url (
	'ftp://ftp.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg',
	'ftp://ftp.proftpd.org/README.MIRRORS',                        # Proftpd
	'ftp://ftp.redhat.com/pub/redhat/linux/README',                # vsftpd
	'ftp://ftp.cisco.com/test.html',                               # Apache FTP
	'ftp://ftp.gwdg.de/pub/mozilla.org/_please_use_ftp5.gwdg.de_', # Empty file

	# TODO: Find a public FTP server using Microsoft FTP service and add it
	)
{
	$url =~ /ftp\:\/\/(.+?)\// and my $server = $1;
	$file = Padre::File->new($url);
	ok( defined($file), 'FTP ' . $server . ': Create Padre::File object' );
	ok( $file->exists,  'FTP ' . $server . ': Exists' );
	my $size = $file->size;
	ok( defined($size), 'FTP ' . $server . ': ' . $size . ' bytes' );
}

done_testing();
