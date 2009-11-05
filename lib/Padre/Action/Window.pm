package Padre::Action::Window;

# Fully encapsulated Window menu

use 5.008;
use strict;
use warnings;
use Padre::Action;
use Padre::Current qw{_CURRENT};

our $VERSION = '0.49';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;
	$self->{alt}  = [];

	# File Navigation
	Padre::Action->new(
		name        => 'window.next_file',
		label       => Wx::gettext('Next File'),
		shortcut    => 'Ctrl-TAB',
		need_editor => 1,
		menu_event  => sub {
			Padre::Wx::Main::on_next_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.previous_file',
		label       => Wx::gettext('Previous File'),
		shortcut    => 'Ctrl-Shift-TAB',
		need_editor => 1,
		menu_event  => sub {
			Padre::Wx::Main::on_prev_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.last_visited_file',
		label       => Wx::gettext('Last Visited File'),
		shortcut    => 'Ctrl-Shift-P',
		need_editor => 1,
		menu_event  => sub {
			Padre::Wx::Main::on_last_visited_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.right_click',
		label       => Wx::gettext('Right Click'),
		shortcut    => 'Alt-/',
		need_editor => 1,
		menu_event  => sub {
			my $editor = $_[0]->current->editor;
			if ($editor) {
				$editor->on_right_down( $_[1] );
			}
		},
	);

	# Window Navigation
	Padre::Action->new(
		name       => 'window.goto_functions_window',
		label      => Wx::gettext('GoTo Functions Window'),
		shortcut   => 'Alt-N',
		menu_event => sub {
			$_[0]->refresh_functions( $_[0]->current );
			$_[0]->show_functions(1);
			$_[0]->functions->focus_on_search;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_outline_window',
		label      => Wx::gettext('GoTo Outline Window'),
		shortcut   => 'Alt-L',
		menu_event => sub {
			$_[0]->show_outline(1);
			$_[0]->outline->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_output_window',
		label      => Wx::gettext('GoTo Output Window'),
		shortcut   => 'Alt-O',
		menu_event => sub {
			$_[0]->show_output(1);
			$_[0]->output->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_syntax_check_window',
		label      => Wx::gettext('GoTo Syntax Check Window'),
		shortcut   => 'Alt-C',
		menu_event => sub {
			$_[0]->show_syntax(1);
			$_[0]->syntax->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_main_window',
		label      => Wx::gettext('GoTo Main Window'),
		shortcut   => 'Alt-M',
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$editor->SetFocus;
		},
	);

	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
