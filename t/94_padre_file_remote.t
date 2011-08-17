#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Padre::File;

if ( !$ENV{PADRE_NETWORK_T} ) {
	plan( tests => 1 );
	SKIP: {
		skip 'This test file requires permission to connect to the internet, set PADRE_NETWORK_T=1 if you want this', 1;
	}
	exit;
}

plan( tests => 80 );

package Wx;

sub gettext { shift; }

package main;

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

foreach my $url ( keys(%HTTP_Tests) ) {
	$file = Padre::File->new($url);
	ok( defined($file), 'HTTP ' . $url . ': Create Padre::File object' );
	ok( $file->{protocol} eq 'http',                 'HTTP ' . $url . ': Check protocol' );
	ok( $file->dirname    eq $HTTP_Tests{$url}->[0], 'HTTP ' . $url . ': Check dirname' );
	ok( $file->basename   eq $HTTP_Tests{$url}->[1], 'HTTP ' . $url . ': Check basename' );
}

my $clone = $file->clone('http://padre.perlide.org/download.html');
ok( defined($clone), 'HTTP: Create clone' );
is( ref($clone), 'Padre::File::HTTP', 'HTTP: Clone object type' );
is( $clone->{protocol}, 'http', 'HTTP: Check clone protocol' );
ok( $clone->size > 0,            'HTTP: Clone file size' );
ok( $clone->mtime >= 1253194791, 'HTTP: Clone mtime' );
is( $clone->basename, 'download.html',             'HTTP: Clone basename' );
is( $clone->dirname,  'http://padre.perlide.org/', 'HTTP: Clone dirname' );
ok( !$clone->can_run, 'HTTP: Clone can not run' );

is( $clone->browse_mtime('/download.html'), $clone->mtime, 'HTTP: browse_mtime' );

###############################################################################
### Padre::File::FTP

# Plain file from CPAN
$file = Padre::File->new('ftp://ftp.cpan.org/pub/CPAN/README');
ok( defined($file), 'FTP: Create Padre::File object' );
is( ref($file), 'Padre::File::FTP', 'FTP: Check module' );
is( $file->{protocol}, 'ftp', 'FTP: Check protocol' );
cmp_ok( $file->size, '>', 0, 'FTP: file size' );
is( $file->basename,   'README',                      'FTP: basename' );
is( $file->dirname,    'ftp://ftp.cpan.org/pub/CPAN', 'FTP: dirname' );
is( $file->servername, 'ftp.cpan.org',                'FTP: servername' );
ok( !$file->can_run, 'FTP: Can not run' );
ok( $file->exists,   'FTP: Exists' );
cmp_ok( $file->mtime, '>=', 918914146, 'FTP: mtime' );
my $firstfile = $file;

# Symlink
$file = Padre::File->new('ftp://ftp.kernel.org/welcome.msg');
ok( defined($file), 'FTP2: Create Padre::File object' );
cmp_ok( $file->size, '>', 0, 'FTP2: file size' );
is( $file->servername, 'ftp.kernel.org',       'FTP2: servername' );
is( $file->dirname,    'ftp://ftp.kernel.org', 'FTP2: servername' );
is( $file->basename,   'welcome.msg',          'FTP2: servername' );
ok( $file->exists, 'FTP2: Exists' );

# Test some FTP servers
foreach my $url (
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
	ok( $file->mtime,   'FTP ' . $server . ': mtime ' . scalar( localtime( $file->mtime ) ) );
}

$clone = $firstfile->clone('ftp://ftp.cpan.org/pub/CPAN/index.html');
ok( defined($clone), 'FTP: Create Padre::File clone' );
is( ref($clone), 'Padre::File::FTP', 'FTP: Check clone module' );
is( $clone->{protocol}, 'ftp', 'FTP: Check clone protocol' );
cmp_ok( $clone->size, '>', 0, 'FTP: clone file size' );
is( $clone->basename, 'index.html', 'FTP: clone basename' );
is( $clone->dirname, 'ftp://ftp.cpan.org/pub/CPAN', 'FTP: clone dirname' );
ok( !$clone->can_run, 'FTP: Clone can not run' );
ok( $clone->exists,   'FTP: Clone exists' );

is( $firstfile->mtime, $clone->browse_mtime('/pub/CPAN/README'), 'FTP: browse_mtime' );

$file = Padre::File->new('ftp://ftp.cpan.org/pub/CPAN/README');
my $file2 = Padre::File->new('ftp://ftp.cpan.org/pub/CPAN/README');
is( $file->size, $file2->size, 'Check file size for two connections' );
is( $file->_ftp, $file2->_ftp, 'Verify connection caching/sharing' );
my $oldconn = $file->_ftp;
is( $file->_ftp->quit, 1, 'Badly disconnect a connection' );
sleep 1; # Required to finish the disconnect
is( $file->_ftp, $file2->_ftp, 'Try auto-reestablishing of the connection' );
isnt( $file->_ftp, $oldconn, 'Check if a new connection was created' );
done_testing();
