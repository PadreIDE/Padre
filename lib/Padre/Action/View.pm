package Padre::Action::View;

# Fully encapsulated View menu

use 5.008;
use strict;
use warnings;
use File::Glob ();

use Padre::Constant ();
use Padre::Current qw{_CURRENT};
use Padre::Locale   ();
use Padre::Util     ('_T');
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.53';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = Padre->ide->config;

	# Create the empty menu as normal
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Can the user move stuff around
	Padre::Action->new(
		name        => 'view.lockinterface',
		label       => _T('Lock User Interface'),
		comment     => _T('Allow the user to move around some of the windows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_lockinterface( $_[1] );
		},
	);

	# Show or hide GUI elements
	Padre::Action->new(
		name        => 'view.output',
		label       => _T('Show Output'),
		comment     => _T('Show the window displaying the standard output and standard error of the running scripts'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_output( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.functions',
		label       => _T('Show Functions'),
		comment     => _T('Show a window listing all the functions in the current document'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			if ( $_[1]->IsChecked ) {
				$_[0]->refresh_functions( $_[0]->current );
				$_[0]->show_functions(1);
			} else {
				$_[0]->show_functions(0);
			}
		},
	);

	# Show or hide GUI elements
	Padre::Action->new(
		name        => 'view.outline',
		label       => _T('Show Outline'),
		comment     => _T('Show a window listing all the parts of the current file (functions, pragmas, modules)'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_outline( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.directory',
		label       => _T('Show Directory Tree'),
		comment     => _T('Show a window with a directory browser of the current project'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_directory( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.show_syntaxcheck',
		label       => _T('Show Syntax Check'),
		comment     => _T('Turn on syntax checking of the current document and show output in a window'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_syntax_check( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.show_errorlist',
		label       => _T('Show Error List'),
		comment     => _T('Show the list of errors received during execution of a script'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_errorlist( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.statusbar',
		label       => _T('Show Status Bar'),
		comment     => _T('Show/hide the status bar at the bottom of the screen'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_statusbar( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.toolbar',
		label       => _T('Show Toolbar'),
		comment     => _T('Show/hide the toolbar at the top of the editor'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_toolbar( $_[1] );
		},
	);

	# Editor Functionality
	Padre::Action->new(
		name        => 'view.lines',
		label       => _T('Show Line Numbers'),
		comment     => _T('Show/hide the line numbers of all the documents on the left side of the window'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_line_numbers( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.folding',
		label       => _T('Show Code Folding'),
		comment     => _T('Show/hide a vertical line on the left hand side of the window to allow folding rows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_code_folding( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.fold_all',
		label       => _T('Fold all'),
		comment     => _T('Fold all the blocks that can be folded (need folding to be enabled)'),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->current->editor->fold_all;
		},
	);

	Padre::Action->new(
		name        => 'view.unfold_all',
		label       => _T('Unfold all'),
		comment     => _T('Unfold all the blocks that can be folded (need folding to be enabled)'),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->current->editor->unfold_all;
		},
	);

	Padre::Action->new(
		name        => 'view.show_calltips',
		label       => _T('Show Call Tips'),
		comment     => _T('When typing in functions allow showing short examples of the function'),
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
		label       => _T('Show Current Line'),
		comment     => _T('Highlight the line where the cursor is'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_currentline( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.rightmargin',
		label       => _T('Show Right Margin'),
		comment     => _T('Show a vertical line indicating the right margin'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_right_margin( $_[1] );
		},
	);

	# Editor Whitespace Layout
	Padre::Action->new(
		name        => 'view.eol',
		label       => _T('Show Newlines'),
		comment     => _T('Show/hide the newlines with special character'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_eol( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.whitespaces',
		label       => _T('Show Whitespaces'),
		comment     => _T('Show/hide the tabs and the spaces with special characters'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_whitespaces( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.indentation_guide',
		label       => _T('Show Indentation Guide'),
		comment     => _T('Show/hide vertical bars at every indentation position on the left of the rows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_indentation_guide( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.word_wrap',
		label       => _T('Word-Wrap'),
		comment     => _T('Wrap long lines'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_word_wrap( $_[1]->IsChecked );
		},
	);

	# Font Size
	Padre::Action->new(
		name       => 'view.font_increase',
		label      => _T('Increase Font Size'),
		comment    => _T('Make the letters bigger in the editor window'),
		shortcut   => 'Ctrl-+',
		menu_event => sub {
			$_[0]->zoom(+1);
		},
	);

	Padre::Action->new(
		name       => 'view.font_decrease',
		label      => _T('Decrease Font Size'),
		comment    => _T('Make the letters smaller in the editor window'),
		shortcut   => 'Ctrl--',
		menu_event => sub {
			$_[0]->zoom(-1);
		},
	);

	Padre::Action->new(
		name       => 'view.font_reset',
		label      => _T('Reset Font Size'),
		comment    => _T('Reset the size of the letters to the default in the editor window'),
		shortcut   => 'Ctrl-0',
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$_[0]->zoom( -1 * $editor->GetZoom );
		},
	);

	# Bookmark Support
	Padre::Action->new(
		name       => 'view.bookmark_set',
		label      => _T('Set Bookmark'),
		comment    => _T('Create a bookmark in the current file current row'),
		shortcut   => 'Ctrl-B',
		menu_event => sub {
			require Padre::Wx::Dialog::Bookmarks;
			Padre::Wx::Dialog::Bookmarks->set_bookmark( $_[0] );
		},
	);

	Padre::Action->new(
		name       => 'view.bookmark_goto',
		label      => _T('Goto Bookmark'),
		comment    => _T('Select a bookmark created earlier and jump to that position'),
		shortcut   => 'Ctrl-Shift-B',
		menu_event => sub {
			require Padre::Wx::Dialog::Bookmarks;
			Padre::Wx::Dialog::Bookmarks->goto_bookmark( $_[0] );
		},
	);


	# Window Effects
	Padre::Action->new(
		name        => 'view.full_screen',
		label       => _T('&Full Screen'),
		comment     => _T('Set Padre in full screen mode'),
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

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
