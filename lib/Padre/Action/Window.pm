package Padre::Action::Window;

# Fully encapsulated Window menu

use 5.008;
use strict;
use warnings;
use Padre::Action;
use Padre::Current qw{_CURRENT};

our $VERSION = '0.62';
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
		name        => 'window.last_visited_file',
		label       => Wx::gettext('Last Visited File'),
		comment     => Wx::gettext('Switch to edit the file that was previously edited (can switch back and forth)'),
		shortcut    => 'Ctrl-Tab',
		need_editor => 1,
		menu_event  => sub {
			Padre::Wx::Main::on_last_visited_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.oldest_visited_file',
		label       => Wx::gettext('Oldest Visited File'),
		comment     => Wx::gettext('Put focus on tab visited the longest time ago.'),
		shortcut    => 'Ctrl-Shift-Tab',
		need_editor => 1,
		menu_event  => sub {
			Padre::Wx::Main::on_oldest_visited_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.next_file',
		label       => Wx::gettext('Next File'),
		comment     => Wx::gettext('Put focus on the next tab to the right'),
		shortcut    => 'Alt-Right',
		need_editor => 1,
		menu_event  => sub {
			Padre::Wx::Main::on_next_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.previous_file',
		label       => Wx::gettext('Previous File'),
		comment     => Wx::gettext('Put focus on the previous tab to the left'),
		shortcut    => 'Alt-Left',
		need_editor => 1,
		menu_event  => sub {
			Padre::Wx::Main::on_prev_pane(@_);
		},
	);

	# TODO: Remove this and the menu option as soon as #750 is fixed
	#       as it's the same like Ctrl-Tab
	Padre::Action->new(
		name        => 'window.last_visited_file_old',
		label       => Wx::gettext('Last Visited File'),
		comment     => Wx::gettext('???'),
		shortcut    => 'Ctrl-Shift-P',
		need_editor => 1,
		menu_event  => sub {
			Padre::Wx::Main::on_last_visited_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.right_click',
		label       => Wx::gettext('Right Click'),
		comment     => Wx::gettext('Imitate clicking on the right mouse button'),
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
		label      => Wx::gettext('Go to Functions Window'),
		comment    => Wx::gettext('Set the focus to the "Functions" window'),
		shortcut   => 'Alt-N',
		menu_event => sub {
			$_[0]->refresh_functions( $_[0]->current );
			$_[0]->show_functions(1);
			$_[0]->functions->focus_on_search;
		},
	);

	# Window Navigation
	Padre::Action->new(
		name       => 'window.goto_todo_window',
		label      => Wx::gettext('Go to Todo Window'),
		comment    => Wx::gettext('Set the focus to the "Todo" window'),
		shortcut   => 'Alt-T',
		menu_event => sub {
			$_[0]->refresh_todo( $_[0]->current );
			$_[0]->show_todo(1);
			$_[0]->todo->focus_on_search;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_outline_window',
		label      => Wx::gettext('Go to Outline Window'),
		comment    => Wx::gettext('Set the focus to the "Outline" window'),
		shortcut   => 'Alt-L',
		menu_event => sub {
			$_[0]->show_outline(1);
			$_[0]->outline->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_output_window',
		label      => Wx::gettext('Go to Output Window'),
		comment    => Wx::gettext('Set the focus to the "Output" window'),
		shortcut   => 'Alt-O',
		menu_event => sub {
			$_[0]->show_output(1);
			$_[0]->output->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_syntax_check_window',
		label      => Wx::gettext('Go to Syntax Check Window'),
		comment    => Wx::gettext('Set the focus to the "Syntax Check" window'),
		shortcut   => 'Alt-C',
		menu_event => sub {
			$_[0]->show_syntax(1);
			$_[0]->syntax->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_main_window',
		label      => Wx::gettext('Go to Main Window'),
		comment    => Wx::gettext('Set the focus to the main editor window'),
		shortcut   => 'Alt-M',
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$editor->SetFocus;
		},
	);

	return $self;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
