#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 20;
use Test::NoWarnings;

use Data::Dumper qw(Dumper);

use t::lib::Padre;
use Padre;
use Padre::DB ();

my $app = Padre->new;

SCOPE: {
	my $current = Padre::DB->get_last_pod;
	ok !defined $current, 'current pod not defined';

	my @pods = Padre::DB->get_recent_pod;
	is_deeply \@pods, [], 'no pods yet'
		or diag Dumper \@pods;
	my @files = Padre::DB->get_recent_files;
	is_deeply \@files, [], 'no files yet';

	ok( ! Padre::DB->add_recent_pod('Test'), 'add_recent_pod' );
	@pods = Padre::DB->get_recent_pod;
	is_deeply \@pods, ['Test'], 'pods';
	is( Padre::DB->get_last_pod, 'Test', 'current is Test' );

	ok( ! Padre::DB->add_recent_pod('Test::More'), 'add_recent_pod' );
	@pods = Padre::DB->get_recent_pod;
	is_deeply \@pods, ['Test::More', 'Test'], 'pods';
	is( Padre::DB->get_last_pod, 'Test::More', 'current is Test::More' );
	
	ok( ! Padre::DB->add_recent_files('Test.pm'), 'add_recent_file' );
	ok( ! Padre::DB->add_recent_files('Test2.pm'), 'add_recent_file 2' );
	@files = Padre::DB->get_recent_files;
	is_deeply \@files, ['Test2.pm', 'Test.pm'], 'files';

	# test delete_recent
	ok( Padre::DB->delete_recent( 'pod' ) );
	@pods = Padre::DB->get_recent_pod;
	is_deeply \@pods, [], 'no pods after delete_recent pod';
	@files = Padre::DB->get_recent_files;
	is_deeply \@files, ['Test2.pm', 'Test.pm'], 'files still remain after delete_recent pod';
	ok( Padre::DB->delete_recent( 'files' ) );
	@files = Padre::DB->get_recent_files;
	is_deeply \@files, [], 'no files after delete_recent files';

# TODO next, previous,
# TODO limit number of items and see what happens
# TODO whne setting an element that was already in the list as recent
# it should become the last one!
}

SCOPE: {
	my @words = qw(One Two Three Four Five Six);
	foreach my $name (@words) {
		Padre::DB->add_recent_pod($name);
	}
	my @pods = Padre::DB->get_recent_pod;
	is_deeply \@pods, [reverse @words], 'pods';
	is( Padre::DB->get_last_pod, 'Six', 'current is Six' );
}

1;