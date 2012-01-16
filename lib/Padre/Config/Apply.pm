package Padre::Config::Apply;

# Dedicated namespace for holding code for applying config changes to
# a running Padre instance.
#
# This delays the loading of all this functionality till it is needed,
# if it is ever needed, and reduces code and dependencies of Padre::Config.

use 5.008;
use strict;
use warnings;
ues Padre::Feature ();

our $VERSION    = '0.93';
our $COMPATIBLE = '0.93';





######################################################################
# Apply Methods

sub main_title {
	$_[0]->lock('refresh_title');
}

sub main_statusbar_template {
	$_[0]->lock('refresh_title');
}

sub main_singleinstance {
	my $main  = shift;
	my $value = shift;
	if ($value) {
		$main->single_instance_start;
	} else {
		$main->single_instance_stop;
	}
	return 1;
}

sub main_singleinstance_port {
	my $main = shift;
	if ( $main->config->main_singleinstance ) {

		# Restart on the new port or the next attempt
		# to use it will produce a new instance.
		$main->single_instance_stop;
		$main->single_instance_start;
	}
}

sub main_lockinterface {
	my $main  = shift;
	my $value = shift;

	# Update the lock status
	$main->aui->lock_panels($value);

	# The toolbar can't dynamically switch between
	# tearable and non-tearable so rebuild it.
	# TO DO: Review this assumption

	# (Ticket #668)
	no warnings;
	if ($Padre::Wx::ToolBar::DOCKABLE) {
		$main->rebuild_toolbar;
	}

	return 1;
}

sub main_functions {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->view->{functions};
	$item->Check($on) if $on != $item->IsChecked;
	$main->view_show( functions => $on );
	$main->aui->Update;
}

sub main_functions_order {
	$_[0]->lock('refresh_functions');
}

sub main_outline {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->view->{outline};
	$item->Check($on) if $on != $item->IsChecked;
	$main->view_show( main_outline => $on );
	$main->aui->Update;
}

sub main_directory {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->view->{directory};
	$item->Check($on) if $on != $item->IsChecked;
	$main->view_panel( directory => $on );
	$main->aui->Update;
}

sub main_directory_order {
	$_[0]->lock('refresh_directory');
}

sub main_directory_panel {
	my $main  = shift;
	my $value = shift;

	# Is it visible and on the wrong side?
	return 1 unless $main->has_directory;
	my $directory = $main->directory;
	return 1 unless $directory->IsShown;
	return 1 unless $directory->side ne $value;

	# Hide and reshow the tool with the new setting
	$main->view_show( directory => 0 );
	$main->view_show( directory => 1 );
	$main->Layout;
	$main->Update;
}

sub main_directory_root {
	$_[0]->lock('refresh_directory');
}

sub main_output {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->view->{output};
	$item->Check($on) if $on != $item->IsChecked;
	$main->view_show( output => $on );
	$main->aui->Update;
}

sub main_syntaxcheck {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->view->{syntaxcheck};
	$item->Check($on) if $on != $item->IsChecked;
	$main->view_show( syntaxcheck => $on );
	$main->aui->Update;
}

sub main_vcs {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->view->{vcs};
	$item->Check($on) if $on != $item->IsChecked;
	$main->view_show( vcs => $on );
	$main->aui->Update;
}

sub main_cpan_explorer {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->view->{cpan_explorer};
	$item->Check($on) if $on != $item->IsChecked;
	$main->view_show( cpan_explorer => $on );
	$main->aui->Update;
}

sub main_panel_debug_breakpoints {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->debug->{panel_breakpoints};
	$item->Check($on) if $on != $item->IsChecked;
	$main->_show_panel_breakpoints($on);
	$main->aui->Update;
}

sub main_panel_debug_output {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->debug->{panel_debug_output};
	$item->Check($on) if $on != $item->IsChecked;
	$main->_show_panel_debug_output($on);
	$main->aui->Update;
}

sub main_pane_debugger {
	my $main = shift;
	my $on   = shift;
	my $item = $main->menu->debug->{panel_debugger};
	$item->Check($on) if $on != $item->IsChecked;
	$main->_show_panel_debugger($on);
	$main->aui->Update;
}

sub main_toolbar {
	$_[0]->show_toolbar( $_[1] );
}

sub editor_linenumbers {
	$_[0]->editor_linenumbers( $_[1] );
}

sub editor_eol {
	$_[0]->editor_eol( $_[1] );
}

sub editor_whitespace {
	$_[0]->editor_whitespace( $_[1] );
}

sub editor_intentationguides {
	$_[0]->editor_indentationguides( $_[1] );
}

sub editor_folding {
	my $main = shift;
	my $show = shift;
	if ($Padre::Feature::VERSION) {
		Padre::Feature::FOLDING() or return;
	} else {
		$main->feature_folding or return;
	}
	if ( $main->can('editor_folding') ) {
		$main->editor_folding($show);
	}
}

sub editor_currentline {
	$_[0]->editor_currentline( $_[1] );
}

sub editor_rightmargin {
	$_[0]->editor_rightmargin( $_[1] );
}

sub editor_style {
	$_[0]->restyle;
}





######################################################################
# Support Functions

1;
