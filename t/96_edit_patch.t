#!/usr/bin/perl

use strict;
use warnings;
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


#my $listview = $treebook->GetListView;
#isa_ok( $listview, 'Wx::ListView' );
#is( $listview->,       8,   'Found siz items' );
#is( $listview->GetColumnCount,     0,   'Found one column' );
#is( $listview->GetColumnWidth(-1), 100, 'Got column width' );

# Load the dialog from configuration

# my $config = $main->config;
# isa_ok( $config, 'Padre::Config' );
# ok( $dialog->config_load($config), '->load ok' );

# The diff (extracted from dialog) to the config should be null,
# except maybe for a potential default font value. This is because
# SetSelectedFont() doesn't work on wxNullFont.

# my $diff = $dialog->config_diff($config);
# if ($diff) {
	# is scalar keys %$diff, 1, 'only one key defined in the diff';
	# ok exists $diff->{editor_font}, 'only key defined is "editor_font"';
# } else {
	# ok !$diff, 'null font loaded, config_diff() returned nothing';
	# ok 1, 'placebo to stick to the plan';
# }

