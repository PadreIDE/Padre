package Padre::Action::View;

# Fully encapsulated View menu

use 5.008;
use strict;
use warnings;
use Padre::Constant ();
use Padre::Locale   ();
use Padre::Wx       ();

our $VERSION = '0.65';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class  = shift;
	my $main   = shift;
	my $self   = bless { main => $main }, $class;
	my $config = $main->config;

	# Can the user move stuff around
	Padre::Action->new(
		name        => 'view.lockinterface',
		label       => Wx::gettext('Lock User Interface'),
		comment     => Wx::gettext('If activated, do not allow moving around some of the windows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_lockinterface( $_[1] );
		},
	);

	# Visible GUI Elements

	Padre::Action->new(
		name  => 'view.output',
		label => Wx::gettext('Show Output'),
		comment =>
			Wx::gettext('Show the window displaying the standard output and standard error of the running scripts'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_output( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.functions',
		label       => Wx::gettext('Show Functions'),
		comment     => Wx::gettext('Show a window listing all the functions in the current document'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_functions( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.todo',
		label       => Wx::gettext('Show To-do List'),
		comment     => Wx::gettext('Show a window listing all todo items in the current document'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_todo( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name    => 'view.outline',
		label   => Wx::gettext('Show Outline'),
		comment => Wx::gettext('Show a window listing all the parts of the current file (functions, pragmas, modules)'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_outline( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.directory',
		label       => Wx::gettext('Show Directory Tree'),
		comment     => Wx::gettext('Show a window with a directory browser of the current project'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_directory( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.show_syntaxcheck',
		label       => Wx::gettext('Show Syntax Check'),
		comment     => Wx::gettext('Turn on syntax checking of the current document and show output in a window'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_syntax( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.show_errorlist',
		label       => Wx::gettext('Show Errors'),
		comment     => Wx::gettext('Show the list of errors received during execution of a script'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_errorlist( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.statusbar',
		label       => Wx::gettext('Show Status Bar'),
		comment     => Wx::gettext('Show/hide the status bar at the bottom of the screen'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_statusbar( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.toolbar',
		label       => Wx::gettext('Show Toolbar'),
		comment     => Wx::gettext('Show/hide the toolbar at the top of the editor'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_toolbar( $_[1] );
		},
	);

	# Editor Functionality

	Padre::Action->new(
		name        => 'view.lines',
		label       => Wx::gettext('Show Line Numbers'),
		comment     => Wx::gettext('Show/hide the line numbers of all the documents on the left side of the window'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_line_numbers( $_[1] );
		},
	);

	Padre::Action->new(
		name    => 'view.folding',
		label   => Wx::gettext('Show Code Folding'),
		comment => Wx::gettext('Show/hide a vertical line on the left hand side of the window to allow folding rows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_code_folding( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.fold_all',
		label       => Wx::gettext('Fold all'),
		comment     => Wx::gettext('Fold all the blocks that can be folded (need folding to be enabled)'),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->current->editor->fold_all;
		},
	);

	Padre::Action->new(
		name        => 'view.unfold_all',
		label       => Wx::gettext('Unfold all'),
		comment     => Wx::gettext('Unfold all the blocks that can be folded (need folding to be enabled)'),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->current->editor->unfold_all;
		},
	);

	Padre::Action->new(
		name        => 'view.show_calltips',
		label       => Wx::gettext('Show Call Tips'),
		comment     => Wx::gettext('When typing in functions allow showing short examples of the function'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->config->set(
				'editor_calltips',
				$_[1]->IsChecked ? 1 : 0,
			);
			$_[0]->config->write;
		},
	);

	Padre::Action->new(
		name        => 'view.currentline',
		label       => Wx::gettext('Show Current Line'),
		comment     => Wx::gettext('Highlight the line where the cursor is'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_currentline( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.rightmargin',
		label       => Wx::gettext('Show Right Margin'),
		comment     => Wx::gettext('Show a vertical line indicating the right margin'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_right_margin( $_[1] );
		},
	);

	# Editor Whitespace Layout

	Padre::Action->new(
		name        => 'view.eol',
		label       => Wx::gettext('Show Newlines'),
		comment     => Wx::gettext('Show/hide the newlines with special character'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_eol( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.whitespaces',
		label       => Wx::gettext('Show Whitespaces'),
		comment     => Wx::gettext('Show/hide the tabs and the spaces with special characters'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_whitespaces( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.indentation_guide',
		label       => Wx::gettext('Show Indentation Guide'),
		comment     => Wx::gettext('Show/hide vertical bars at every indentation position on the left of the rows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_indentation_guide( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.word_wrap',
		label       => Wx::gettext('Word-Wrap'),
		comment     => Wx::gettext('Wrap long lines'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_word_wrap( $_[1]->IsChecked );
		},
	);

	# Font Size

	Padre::Action->new(
		name       => 'view.font_increase',
		label      => Wx::gettext('Increase Font Size'),
		comment    => Wx::gettext('Make the letters bigger in the editor window'),
		shortcut   => 'Ctrl-+',
		menu_event => sub {
			$_[0]->zoom(+1);
		},
	);

	Padre::Action->new(
		name       => 'view.font_decrease',
		label      => Wx::gettext('Decrease Font Size'),
		comment    => Wx::gettext('Make the letters smaller in the editor window'),
		shortcut   => 'Ctrl--',
		menu_event => sub {
			$_[0]->zoom(-1);
		},
	);

	Padre::Action->new(
		name       => 'view.font_reset',
		label      => Wx::gettext('Reset Font Size'),
		comment    => Wx::gettext('Reset the size of the letters to the default in the editor window'),
		shortcut   => 'Ctrl-0',
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$_[0]->zoom( -1 * $editor->GetZoom );
		},
	);

	# Bookmark Support

	Padre::Action->new(
		name       => 'view.bookmark_set',
		label      => Wx::gettext('Set Bookmark'),
		comment    => Wx::gettext('Create a bookmark in the current file current row'),
		shortcut   => 'Ctrl-B',
		menu_event => sub {
			require Padre::Wx::Dialog::Bookmarks;
			Padre::Wx::Dialog::Bookmarks->set_bookmark( $_[0] );
		},
	);

	Padre::Action->new(
		name       => 'view.bookmark_goto',
		label      => Wx::gettext('Goto Bookmark'),
		comment    => Wx::gettext('Select a bookmark created earlier and jump to that position'),
		shortcut   => 'Ctrl-Shift-B',
		menu_event => sub {
			require Padre::Wx::Dialog::Bookmarks;
			Padre::Wx::Dialog::Bookmarks->goto_bookmark( $_[0] );
		},
	);

	# Window Effects

	Padre::Action->new(
		name        => 'view.full_screen',
		label       => Wx::gettext('&Full Screen'),
		comment     => Wx::gettext('Set Padre in full screen mode'),
		shortcut    => 'F11',
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			if ( $_[0]->IsFullScreen ) {
				$_[0]->ShowFullScreen(0);
			} else {
				$_[0]->ShowFullScreen(
					1,
					Wx::wxFULLSCREEN_NOCAPTION | Wx::wxFULLSCREEN_NOBORDER
				);
			}
			return;
		},
	);

	return $self;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
