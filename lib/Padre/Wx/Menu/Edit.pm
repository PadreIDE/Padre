package Padre::Wx::Menu::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Current  qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.25';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

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
			Padre::Current->editor->Undo;
		},
	);

	$self->{redo} = $self->Append(
		Wx::wxID_REDO,
		Wx::gettext("&Redo")
	);
	Wx::Event::EVT_MENU( $main, # Ctrl-Y
		$self->{redo},
		sub {
			Padre::Current->editor->Redo;
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
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_start;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$edit_select->Append( -1,
			Wx::gettext("Mark selection end\tCtrl-]")
		),
		sub {
			my $editor = Padre::Current->editor or return;
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
			Padre::Current->editor->Copy;
		}
	);

	$self->{cut} = $self->Append(
		Wx::wxID_CUT,
		Wx::gettext("Cu&t\tCtrl-X")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{cut},
		sub {
			Padre::Current->editor->Cut;
		}
	);

	$self->{paste} = $self->Append(
		Wx::wxID_PASTE,
		Wx::gettext("&Paste\tCtrl-V")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{paste},
		sub { 
			my $editor = Padre::Current->editor or return;
			$editor->Paste;
		},
	);

	$self->AppendSeparator;





	# Miscellaneous Actions
	$self->{goto} = $self->Append( -1,
		Wx::gettext("&Goto\tCtrl-G")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{goto},
		\&Padre::Wx::Main::on_goto,
	);

	$self->{autocomp} = $self->Append( -1,
		Wx::gettext("&AutoComp\tCtrl-P")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{autocomp},
		\&Padre::Wx::Main::on_autocompletition,
	);

	$self->{brace_match} = $self->Append( -1,
		Wx::gettext("&Brace matching\tCtrl-1")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{brace_match},
		\&Padre::Wx::Main::on_brace_matching,
	);

	$self->{join_lines} = $self->Append( -1,
		Wx::gettext("&Join lines\tCtrl-J")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{join_lines},
		\&Padre::Wx::Main::on_join_lines,
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
		\&Padre::Wx::Main::on_comment_out_block,
	);

	$self->{uncomment} = $self->Append( -1,
		Wx::gettext("&Uncomment Selected Lines\tCtrl-Shift-M")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{uncomment},
		\&Padre::Wx::Main::on_uncomment_block,
	);
	$self->AppendSeparator;





	# Tabs And Spaces
	$self->{tabs} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Tabs and Spaces"),
		$self->{tabs},
	);

	$self->{tabs_to_spaces} = $self->{tabs}->Append( -1,
		Wx::gettext("Tabs to Spaces...")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{tabs_to_spaces},
		sub {
			$_[0]->on_tab_and_space('Tab_to_Space');
		},
	);

	$self->{spaces_to_tabs} = $self->{tabs}->Append( -1,
		Wx::gettext("Spaces to Tabs...")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{spaces_to_tabs},
		sub {
			$_[0]->on_tab_and_space('Space_to_Tab');
		},
	);

	$self->{tabs}->AppendSeparator;

	$self->{delete_trailing} = $self->{tabs}->Append( -1,
		Wx::gettext("Delete Trailing Spaces")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{delete_trailing},
		sub {
			$DB::single = $DB::single = 1; # stupdily duplicated to avoid warning
			$_[0]->on_delete_ending_space;
		},
	);

	$self->{delete_leading} = $self->{tabs}->Append( -1,
		Wx::gettext("Delete Leading Spaces")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{delete_leading},
		sub {
			$_[0]->on_delete_leading_space;
		},
	);





	# Upper and Lower Case
	$self->{case} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Upper/Lower Case"),
		$self->{case},
	);

	$self->{case_upper} = $self->{case}->Append( -1,
		Wx::gettext("Upper All\tCtrl-Shift-U"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{case_upper},
		sub {
			$_[0]->current->editor->UpperCase;
		},
	);

	$self->{case_lower} = $self->{case}->Append( -1,
		Wx::gettext("Lower All\tCtrl-U"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{case_lower},
		sub {
			$_[0]->current->editor->LowerCase;
		},
	);

	$self->AppendSeparator;





	# Diff
	$self->{diff} = $self->Append( -1,
		Wx::gettext("Diff")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{diff},
		\&Padre::Wx::Main::on_diff,
	);

	$self->{insert_from_file} = $self->Append( -1,
		Wx::gettext("Insert From File...")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{insert_from_file},
		\&Padre::Wx::Main::on_insert_from_file,
	);

	$self->AppendSeparator;





	# User Preferences
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Preferences")
		),
		\&Padre::Wx::Main::on_preferences,
	);





	return $self;
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $document = $current->document;
	my $editor   = $current->editor || 0;
	my $text     = $current->text;

	# Handle the simple cases
	my $doc = $document ? 1 : 0;
	$self->{ goto             }->Enable($doc);
	$self->{ autocomp         }->Enable($doc);
	$self->{ brace_match      }->Enable($doc);
	$self->{ join_lines       }->Enable($doc);
	$self->{ snippets         }->Enable($doc);
	$self->{ comment_out      }->Enable($doc);
	$self->{ uncomment        }->Enable($doc);
	$self->{ diff             }->Enable($doc);
	$self->{ insert_from_file }->Enable($doc);
	$self->{ case_upper       }->Enable($doc);
	$self->{ case_lower       }->Enable($doc);
	$self->{ tabs_to_spaces   }->Enable($doc);
	$self->{ spaces_to_tabs   }->Enable($doc);
	$self->{ delete_leading   }->Enable($doc);
	$self->{ delete_trailing  }->Enable($doc);

	# Handle the complex cases
	my $selection = !! ( defined $text and $text ne '' );
	$self->{undo}->Enable( $editor and $editor->CanUndo );
	$self->{redo}->Enable( $editor and $editor->CanRedo );
	$self->{cut}->Enable( $selection );
	$self->{copy}->Enable( $selection );
	$self->{paste}->Enable( $editor and $editor->CanPaste );

	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
