package Padre::Wx::Menu::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Submenu ();

our $VERSION = '0.20';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Undo/Redo
	$self->{edit_undo} = $self->Append(
		Wx::wxID_UNDO,
		Wx::gettext("&Undo")
	);
	Wx::Event::EVT_MENU( $main, # Ctrl-Z
		$self->{edit_undo},
		sub {
			Padre::Documents->current->editor->Undo;
		},
	);

	$self->{edit_redo} = $self->Append(
		Wx::wxID_REDO,
		Wx::gettext("&Redo")
	);
	Wx::Event::EVT_MENU( $main, # Ctrl-Y
		$self->{edit_redo},
		sub {
			Padre::Documents->current->editor->Redo;
		},
	);

	$self->AppendSeparator;





	# Selection
	my $self_edit_select = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Select"),
		$self_edit_select
	);
	Wx::Event::EVT_MENU( $main,
		$self_edit_select->Append(
			Wx::wxID_SELECTALL,
			Wx::gettext("Select all\tCtrl-A")
		),
		sub {
			\&Padre::Wx::Editor::text_select_all(@_);
		},
	);

	$self_edit_select->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$self_edit_select->Append( -1,
			Wx::gettext("Mark selection start\tCtrl-[")
		),
		sub {
			my $editor = Padre->ide->wx->main_window->selected_editor or return;
			$editor->text_selection_mark_start;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self_edit_select->Append( -1,
			Wx::gettext("Mark selection end\tCtrl-]")
		),
		sub {
			my $editor = Padre->ide->wx->main_window->selected_editor or return;
			$editor->text_selection_mark_end;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self_edit_select->Append( -1,
			Wx::gettext("Clear selection marks")
		),
		\&Padre::Wx::Editor::text_selection_clear_marks,
	);





	# Cut and Paste
	$self->{edit_copy} = $self->Append(
		Wx::wxID_COPY,
		Wx::gettext("&Copy\tCtrl-C")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_copy},
		sub {
			Padre->ide->wx->main_window->selected_editor->Copy;
		}
	);

	$self->{edit_cut} = $self->Append(
		Wx::wxID_CUT,
		Wx::gettext("Cu&t\tCtrl-X")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_cut},
		sub {
			Padre->ide->wx->main_window->selected_editor->Cut;
		}
	);

	$self->{edit_paste} = $self->Append(
		Wx::wxID_PASTE,
		Wx::gettext("&Paste\tCtrl-V")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_paste},
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

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Ac&k")
		),
		\&Padre::Wx::Ack::on_ack,
	);

	$self->{edit_goto} = $self->Append( -1,
		Wx::gettext("&Goto\tCtrl-G")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_goto},
		\&Padre::Wx::MainWindow::on_goto,
	);

	$self->{edit_autocomp} = $self->Append( -1,
		Wx::gettext("&AutoComp\tCtrl-P")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_autocomp},
		\&Padre::Wx::MainWindow::on_autocompletition,
	);

	$self->{edit_brace_match} = $self->Append( -1,
		Wx::gettext("&Brace matching\tCtrl-1")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_brace_match},
		\&Padre::Wx::MainWindow::on_brace_matching,
	);

	$self->{edit_join_lines} = $self->Append( -1,
		Wx::gettext("&Join lines\tCtrl-J")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_join_lines},
		\&Padre::Wx::MainWindow::on_join_lines,
	);

	$self->{edit_snippets} = $self->Append( -1,
		Wx::gettext("Snippets\tCtrl-Shift-A")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_snippets},
		sub {
			Padre::Wx::Dialog::Snippets->snippets(@_);
		},
	); 

	$self->AppendSeparator;





	# Commenting
	$self->{edit_comment_out} = $self->Append( -1,
		Wx::gettext("&Comment Selected Lines\tCtrl-M")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_comment_out},
		\&Padre::Wx::MainWindow::on_comment_out_block,
	);

	$self->{edit_uncomment} = $self->Append( -1,
		Wx::gettext("&Uncomment Selected Lines\tCtrl-Shift-M")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_uncomment},
		\&Padre::Wx::MainWindow::on_uncomment_block,
	);
	$self->AppendSeparator;





	# Tabs And Spaces
	my $self_edit_tab = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Tabs and Spaces"),
		$self_edit_tab
	);
	Wx::Event::EVT_MENU( $main,
		$self_edit_tab->Append( -1,
			Wx::gettext("Tabs to Spaces...")
		),
		sub {
			$_[0]->on_tab_and_space('Tab_to_Space');
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self_edit_tab->Append( -1,
			Wx::gettext("Spaces to Tabs...")
		),
		sub {
			$_[0]->on_tab_and_space('Space_to_Tab');
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self_edit_tab->Append( -1,
			Wx::gettext("Delete Trailing Spaces")
		),
		sub {
			$_[0]->on_delete_ending_space;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self_edit_tab->Append( -1,
			Wx::gettext("Delete Leading Spaces")
		),
		sub {
			$_[0]->on_delete_leading_space;
		},
	);





	# Upper and Lower Case
	my $self_edit_case = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Upper/Lower Case"),
		$self_edit_case
	);
	Wx::Event::EVT_MENU( $main,
		$self_edit_case->Append( -1,
			Wx::gettext("Upper All\tCtrl-Shift-U")
		),
		sub {
			Padre::Documents->current->editor->UpperCase;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self_edit_case->Append( -1,
			Wx::gettext("Lower All\tCtrl-U")
		),
		sub {
			Padre::Documents->current->editor->LowerCase;
		},
	);

	$self->AppendSeparator;





	# Diff
	$self->{edit_diff} = $self->Append( -1,
		Wx::gettext("Diff")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_diff},
		\&Padre::Wx::MainWindow::on_diff,
	);

	$self->{edit_insert_from_file} = $self->Append( -1,
		Wx::gettext("Insert From File...")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{edit_insert_from_file},
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
	$self->{ edit_goto             }->Enable($doc);
	$self->{ edit_autocomp         }->Enable($doc);
	$self->{ edit_brace_match      }->Enable($doc);
	$self->{ edit_join_lines       }->Enable($doc);
	$self->{ edit_snippets         }->Enable($doc);
	$self->{ edit_comment_out      }->Enable($doc);
	$self->{ edit_uncomment        }->Enable($doc);
	$self->{ edit_diff             }->Enable($doc);
	$self->{ edit_insert_from_file }->Enable($doc);

	# Handle the complex cases
	my $editor    = $document ? $document->editor : 0;
	my $selected  = $editor ? $editor->GetSelectedText : '';
	my $selection = !! ( defined $selected and $selected ne '' );
	$self->{edit_undo}->Enable( $editor and $editor->CanUndo );
	$self->{edit_redo}->Enable( $editor and $editor->CanRedo );
	$self->{edit_cut}->Enable( $selection );
	$self->{edit_copy}->Enable( $selection );
	$self->{edit_paste}->Enable( $editor and $editor->CanPaste );

	return 1;
}

1;
