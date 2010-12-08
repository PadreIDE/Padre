#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 6;
}

use Test::NoWarnings;
use t::lib::Padre;

use Data::Dumper qw(Dumper);
use DBI;
use File::Copy qw(copy);
use File::Spec;
use File::Temp qw(tempdir);

use Padre::DB::Migrate ();

my $dir = tempdir( CLEANUP => 1 );
my $dbfile = File::Spec->catfile( $dir, 'padre_test.db' );

my $timeline = File::Spec->catfile( $dir, 'timeline' );
mkdir $timeline;

my @expected = (
	{},
	{   modules  => 1,
		history  => 1,
		snippets => 1,
		hostconf => 1,
	},
	{   modules  => 1,
		history  => 1,
		snippets => 1,
		hostconf => 1,
		plugin   => 1,
	},
	{   history  => 1,
		snippets => 1,
		hostconf => 1,
		plugin   => 1,
	},
	{   history  => 1,
		snippets => 1,
		hostconf => 1,
		plugin   => 1,
		bookmark => 1,
	},
	{   history  => 1,
		snippets => 1,
		hostconf => 1,
		plugin   => 1,
		bookmark => 1,
		session  => 1
	},
);

SCOPE:
for my $v ( 1 .. 5 ) {
	copy( File::Spec->catdir( 'share', 'timeline', "migrate-$v.pl" ), $timeline ) or die $!;

	import Padre::DB::Migrate {
		create        => 1,
		tables        => ['Modules'],
		file          => $dbfile,
		user_revision => $v,         # TODO test what if there is a mismatch
		timeline      => $timeline,

		# Acceleration options (remove these if they cause trouble)
		array      => 1,
		xsaccessor => 0,             # TODO was 1 but that generated the following error:

		# Cannot replace existing subroutine 'value' in package 'main::Hostconf' with an XS implementation. If you wish to force a rep
		# lacement, add the 'replace => 1' parameter to the arguments of 'use Class::XSAccessor::Array'. at (eval 37) line 226
		# BEGIN failed--compilation aborted at (eval 37) line 230.
	}; #, '-DEBUG';

	my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile", "", "" );

	my $sth = $dbh->table_info( undef, 'main', undef, 'TABLE', {} );
	$sth->execute;

	my %tables;
	while ( my $result = $sth->fetchrow_hashref('NAME_lc') ) {

		#diag Dumper $result;
		$tables{ $result->{table_name} } = 1;
	}

	#diag Dumper \%tables;

	is_deeply( \%tables, $expected[$v], "tables v $v" );
}


1;
