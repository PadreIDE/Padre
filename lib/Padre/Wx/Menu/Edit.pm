package Padre::Wx::Menu::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Submenu ();

our $VERSION = '0.22';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Undo/Redo
	$self->{undo} = $self->Append(
		Wx::wxID_UNDO,
		Wx::gettext("&Undo")
	);
	Wx::Event::EVT_MENU( $main, # Ctrl-Z
		$self->{undo},
		sub {
			Padre::Documents->current->editor->Undo;
		},
	);

	$self->{redo} = $self->Append(
		Wx::wxID_REDO,
		Wx::gettext("&Redo")
	);
	Wx::Event::EVT_MENU( $main, # Ctrl-Y
		$self->{redo},
		sub {
			Padre::Documents->current->editor->Redo;
		},
	);

	$self->AppendSeparator;





	# Selection
	my $edit_select = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Select"),
		$edit_select
	);
	Wx::Event::EVT_MENU( $main,
		$edit_select->Append(
			Wx::wxID_SELECTALL,
			Wx::gettext("Select all\tCtrl-A")
		),
		sub {
			\&Padre::Wx::Editor::text_select_all(@_);
		},
	);

	$edit_select->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$edit_select->Append( -1,
			Wx::gettext("Mark selection start\tCtrl-[")
		),
		sub {
			my $editor = Padre->ide->wx->main_window->selected_editor or return;
			$editor->text_selection_mark_start;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$edit_select->Append( -1,
			Wx::gettext("Mark selection end\tCtrl-]")
		),
		sub {
			my $editor = Padre->ide->wx->main_window->selected_editor or return;
			$editor->text_selection_mark_end;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$edit_select->Append( -1,
			Wx::gettext("Clear selection marks")
		),
		\&Padre::Wx::Editor::text_selection_clear_marks,
	);





	# Cut and Paste
	$self->{copy} = $self->Append(
		Wx::wxID_COPY,
		Wx::gettext("&Copy\tCtrl-C")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{copy},
		sub {
			Padre->ide->wx->main_window->selected_editor->Copy;
		}
	);

	$self->{cut} = $self->Append(
		Wx::wxID_CUT,
		Wx::gettext("Cu&t\tCtrl-X")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{cut},
		sub {
			Padre->ide->wx->main_window->selected_editor->Cut;
		}
	);

	$self->{paste} = $self->Append(
		Wx::wxID_PASTE,
		Wx::gettext("&Paste\tCtrl-V")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{paste},
		sub { 
			my $editor = Padre->ide->wx->main_window->selected_editor or return;
			$editor->Paste;
		},
	);

	$self->AppendSeparator;





	# Search and Replace
	Wx::Event::EVT_MENU( $main,
		$self->Append(
			Wx::wxID_FIND,
			Wx::gettext("&Find\tCtrl-F")
		),
		sub {
			Padre::Wx::Dialog::Find->find(@_)
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Find Next\tF3")
		),
		sub {
			Padre::Wx::Dialog::Find->find_next(@_);
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Find Previous\tShift-F3")
		),
		sub {
			Padre::Wx::Dialog::Find->find_previous(@_);
		},
	);

	$self->AppendSeparator;

	# Quick Find: Press F3 to start search with selected text
	$self->{quick_find} = $self->AppendCheckItem( -1,
		Wx::gettext("Quick Find")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{quick_find},
		sub {
			Padre->ide->config->{is_quick_find} = $_[1]->IsChecked ? 1 : 0;
			return;
		},
	);

	# Incremental find (#60)
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Find Next\tF4") ),
		sub {
			$_[0]->find->search('next');
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Find Previous\tShift-F4") ),
		sub {
			$_[0]->find->search('previous');
		}
	);

	$self->AppendSeparator;

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Ac&k")
		),
		\&Padre::Wx::Ack::on_ack,
	);

	$self->{goto} = $self->Append( -1,
		Wx::gettext("&Goto\tCtrl-G")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{goto},
		\&Padre::Wx::MainWindow::on_goto,
	);

	$self->{autocomp} = $self->Append( -1,
		Wx::gettext("&AutoComp\tCtrl-P")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{autocomp},
		\&Padre::Wx::MainWindow::on_autocompletition,
	);

	$self->{brace_match} = $self->Append( -1,
		Wx::gettext("&Brace matching\tCtrl-1")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{brace_match},
		\&Padre::Wx::MainWindow::on_brace_matching,
	);

	$self->{join_lines} = $self->Append( -1,
		Wx::gettext("&Join lines\tCtrl-J")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{join_lines},
		\&Padre::Wx::MainWindow::on_join_lines,
	);

	$self->{snippets} = $self->Append( -1,
		Wx::gettext("Snippets\tCtrl-Shift-A")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{snippets},
		sub {
			Padre::Wx::Dialog::Snippets->snippets(@_);
		},
	); 

	$self->AppendSeparator;





	# Commenting
	$self->{comment_out} = $self->Append( -1,
		Wx::gettext("&Comment Selected Lines\tCtrl-M")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{comment_out},
		\&Padre::Wx::MainWindow::on_comment_out_block,
	);

	$self->{uncomment} = $self->Append( -1,
		Wx::gettext("&Uncomment Selected Lines\tCtrl-Shift-M")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{uncomment},
		\&Padre::Wx::MainWindow::on_uncomment_block,
	);
	$self->AppendSeparator;





	# Tabs And Spaces
	my $edit_tab = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Tabs and Spaces"),
		$edit_tab
	);
	Wx::Event::EVT_MENU( $main,
		$edit_tab->Append( -1,
			Wx::gettext("Tabs to Spaces...")
		),
		sub {
			$_[0]->on_tab_and_space('Tab_to_Space');
		},
	);
	Wx::Event::EVT_MENU( $main,
		$edit_tab->Append( -1,
			Wx::gettext("Spaces to Tabs...")
		),
		sub {
			$_[0]->on_tab_and_space('Space_to_Tab');
		},
	);
	Wx::Event::EVT_MENU( $main,
		$edit_tab->Append( -1,
			Wx::gettext("Delete Trailing Spaces")
		),
		sub {
			$_[0]->on_delete_ending_space;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$edit_tab->Append( -1,
			Wx::gettext("Delete Leading Spaces")
		),
		sub {
			$_[0]->on_delete_leading_space;
		},
	);





	# Upper and Lower Case
	my $edit_case = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Upper/Lower Case"),
		$edit_case
	);
	Wx::Event::EVT_MENU( $main,
		$edit_case->Append( -1,
			Wx::gettext("Upper All\tCtrl-Shift-U")
		),
		sub {
			Padre::Documents->current->editor->UpperCase;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$edit_case->Append( -1,
			Wx::gettext("Lower All\tCtrl-U")
		),
		sub {
			Padre::Documents->current->editor->LowerCase;
		},
	);

	$self->AppendSeparator;





	# Diff
	$self->{diff} = $self->Append( -1,
		Wx::gettext("Diff")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{diff},
		\&Padre::Wx::MainWindow::on_diff,
	);

	$self->{insert_from_file} = $self->Append( -1,
		Wx::gettext("Insert From File...")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{insert_from_file},
		\&Padre::Wx::MainWindow::on_insert_from_file,
	);

	$self->AppendSeparator;





	# User Preferences
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Preferences")
		),
		\&Padre::Wx::MainWindow::on_preferences,
	);





	return $self;
}

sub refresh {
	my $self     = shift;
	my $document = Padre::Documents->current;
	my $doc      = $document ? 1 : 0;

	# Handle the simple cases
	$self->{ goto             }->Enable($doc);
	$self->{ autocomp         }->Enable($doc);
	$self->{ brace_match      }->Enable($doc);
	$self->{ join_lines       }->Enable($doc);
	$self->{ snippets         }->Enable($doc);
	$self->{ comment_out      }->Enable($doc);
	$self->{ uncomment        }->Enable($doc);
	$self->{ diff             }->Enable($doc);
	$self->{ insert_from_file }->Enable($doc);

	# Handle the complex cases
	my $editor    = $document ? $document->editor : 0;
	my $selected  = $editor ? $editor->GetSelectedText : '';
	my $selection = !! ( defined $selected and $selected ne '' );
	$self->{undo}->Enable( $editor and $editor->CanUndo );
	$self->{redo}->Enable( $editor and $editor->CanRedo );
	$self->{cut}->Enable( $selection );
	$self->{copy}->Enable( $selection );
	$self->{paste}->Enable( $editor and $editor->CanPaste );

	return 1;
}

1;
