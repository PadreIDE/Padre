#!/usr/bin/perl

use strict;
use warnings;

# Turn on $OUTPUT_AUTOFLUSH
$| = 1;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 27;
}

use Test::NoWarnings;
use t::lib::Padre;
use Padre::Wx;
use Padre;
use_ok('Padre::Wx::Dialog::Patch');

# Create the IDE
my $padre = new_ok('Padre');
my $main  = $padre->wx->main;
isa_ok( $main, 'Padre::Wx::Main' );

# Create the patch dialog
my $dialog = new_ok( 'Padre::Wx::Dialog::Patch', [$main] );

# Check the radiobox properties
my $against = $dialog->against;
isa_ok( $against, 'Wx::RadioBox' );

# Check the file1 choice properties
my $file1 = $dialog->file1;
isa_ok( $file1, 'Wx::Choice' );

# Check the file2 choice properties
my $file2 = $dialog->file2;
isa_ok( $file2, 'Wx::Choice' );

######
# let's check our subs/methods.
######

my @subs = qw( apply_patch current_files file1_list_svn file2_list_patch
	file2_list_type file_lists_saved filename_url make_patch_diff
	make_patch_svn new on_action on_against process_clicked run
	set_selection_file1 set_selection_file2 set_up test_svn);

use_ok( 'Padre::Wx::Dialog::Patch', @subs );

foreach my $subs (@subs) {
	can_ok( 'Padre::Wx::Dialog::Patch', $subs );
}

