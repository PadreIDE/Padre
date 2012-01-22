package Padre::Config::Apply;

=pod

=head1 NAME

Padre::Config::Apply - Implements on-the-fly configuration changes

=head1 SYNOPSIS

    # When the view state of the directory changes we update the menu
    # check status and show/hide the panel inside of an update lock.
    sub main_directory {
         my $main = shift;
         my $new  = shift;
         my $item = $main->menu->view->{directory};
         my $lock = $main->lock( 'UPDATE', 'AUI' );
         $item->Check($new) if $new != $item->IsChecked;
         $main->show_view( directory => $new );
    }

=head1 DESCRIPTION

B<Padre::Config::Apply> allows L<Padre> to apply changes to configuration
to the IDE on the fly instead of requiring a restart.

Centralising the implementation of this functionality allows loading to
be delayed until dynamic config change is actually required, and allow
changes to configuration to be made by several different parts of Padre,
including both the simple and advanced Preferences dialogs, and the online
configuration sync system.

=head2 Methodology

Functions in this module are named after the matching configuration
property, and are called by L<Padre::Config/apply> when the value being
set is different to the current value.

Because functions are B<only> called when the configuration value has
changed, functions where are not required to do change detection of their
own.

Functions are called with three parameters. The first parameter is the
L<Padre::Wx::Main> main window object, the second is the new value of the
configuration property, and the third is the previous value of the
configuration property.

=cut

use 5.008;
use strict;
use warnings;
use Padre::Feature ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';





######################################################################
# Apply Functions

sub main_title {
	$_[0]->lock('refresh_title');
}

sub main_statusbar_template {
	$_[0]->lock('refresh_title');
}

sub main_singleinstance {
	my $main = shift;
	my $new  = shift;
	if ($new) {
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
	my $main = shift;
	my $new  = shift;

	# Update the lock status
	$main->aui->lock_panels($new);

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
	my $new  = shift;
	my $item = $main->menu->view->{functions};
	my $lock = $main->lock( 'UPDATE', 'AUI', 'refresh_functions' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( functions => $new );
}

sub main_functions_panel {
	apply_panel( functions => @_ );
}

sub main_functions_order {
	$_[0]->lock('refresh_functions');
}

sub main_outline {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->view->{outline};
	my $lock = $main->lock( 'UPDATE', 'AUI', 'refresh_outline' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( main_outline => $new );
}

sub main_outline_panel {
	apply_panel( outline => @_ );
}

sub main_directory {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->view->{directory};
	my $lock = $main->lock( 'UPDATE', 'AUI', 'refresh_directory' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( directory => $new );
}

sub main_directory_panel {
	apply_panel( directory => @_ );
}

sub main_directory_order {
	$_[0]->lock('refresh_directory');
}

sub main_directory_root {
	$_[0]->lock('refresh_directory');
}

sub main_output {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->view->{output};
	my $lock = $main->lock( 'UPDATE', 'AUI' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( output => $new );
}

sub main_output_panel {
	apply_panel( output => @_ );
}

sub main_syntax {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->view->{syntax};
	my $lock = $main->lock( 'UPDATE', 'AUI', 'refresh_syntax' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( syntax => $new );
}

sub main_syntax_panel {
	apply_panel( syntax => @_ );
}

sub main_vcs {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->view->{vcs};
	my $lock = $main->lock( 'UPDATE', 'AUI', 'refresh_vcs' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( vcs => $new );
}

sub main_vcs_panel {
	apply_panel( vcs => @_ );
}

sub main_cpan {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->view->{cpan};
	my $lock = $main->lock( 'UPDATE', 'AUI' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( cpan => $new );
}

sub main_cpan_panel {
	apply_panel( cpan => @_ );
}

sub main_debugger {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->debug->{debugger};
	my $lock = $main->lock( 'UPDATE', 'AUI' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( debugger => $new );
}

sub main_breakpoints {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->debug->{breakpoints};
	my $lock = $main->lock( 'UPDATE', 'AUI' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( breakpoints => $new );
}

sub main_debugoutput {
	my $main = shift;
	my $new  = shift;
	my $item = $main->menu->debug->{debugoutput};
	my $lock = $main->lock( 'UPDATE', 'AUI' );
	$item->Check($new) if $new != $item->IsChecked;
	$main->show_view( debugoutput => $new );
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

sub editor_currentline_color {
	$_[0]->editor_currentline_color( $_[1] );
}

sub editor_rightmargin {
	$_[0]->editor_rightmargin( $_[1] );
}

sub editor_font {
	$_[0]->restyle;
}

sub editor_style {
	$_[0]->restyle;
}





######################################################################
# Support Functions

sub apply_panel {
	my $name = shift;
	my $main = shift;
	my $has  = "has_$name";
	return unless $main->$has();
	return unless $main->find_view( $main->$name() );
	$main->show_view( $name => 0 );
	$main->show_view( $name => 1 );
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
