package Padre::Wx::Menu;

use 5.008;
use strict;
use warnings;
use Params::Util             qw{_INSTANCE};
use Padre::Util              ();
use Padre::Wx                ();
use Padre::Wx::Menu::File    ();
use Padre::Wx::Menu::View    ();
use Padre::Wx::Menu::Perl    ();
use Padre::Wx::Menu::Run     ();
use Padre::Wx::Menu::Plugins ();
use Padre::Wx::Menu::Help    ();
use Padre::Documents         ();

our $VERSION = '0.20';





#####################################################################
# Construction, Setup, and Accessors

use Class::XSAccessor
	getters => {
		win          => 'win',
		wx           => 'wx',

		# Don't add accessors to here until they have been
		# upgraded to be fully encapsulated classes.
		file         => 'file',
		view         => 'view',
		perl         => 'perl',
		run          => 'run',
		plugins      => 'plugins',
		help         => 'help',
		experimental => 'experimental',
	};

sub new {
	my $class  = shift;
	my $main   = shift;
	my $self   = bless {}, $class;

	# Generate the individual menus
	$self->{win}     = $main;
	$self->{file}    = Padre::Wx::Menu::File->new($main);
	$self->{edit}    = $self->menu_edit( $main );
	$self->{view}    = Padre::Wx::Menu::View->new($main);
	$self->{perl}    = Padre::Wx::Menu::Perl->new($main);
	$self->{run}     = Padre::Wx::Menu::Run->new($main);
	$self->{plugins} = Padre::Wx::Menu::Plugins->new($main);
	$self->{window}  = $self->menu_window( $main );
	$self->{help}    = Padre::Wx::Menu::Help->new($main);

	# Generate the final menubar
	$self->{wx} = Wx::MenuBar->new;
	$self->wx->Append( $self->file->wx,    Wx::gettext("&File")    );
	$self->wx->Append( $self->{edit},      Wx::gettext("&Edit")    );
	$self->wx->Append( $self->view->wx,    Wx::gettext("&View")    );
	$self->wx->Append( $self->run->wx,     Wx::gettext("&Run")     );
	$self->wx->Append( $self->plugins->wx, Wx::gettext("Pl&ugins") );
	$self->wx->Append( $self->{window},    Wx::gettext("&Window")  );
	$self->wx->Append( $self->help->wx,    Wx::gettext("&Help")    );

	my $config = Padre->ide->config;
	if ( $config->{experimental} ) {
		# Create the Experimental menu
		# All the crap that doesn't work, have a home,
		# or should never be seen be real users goes here.
		require Padre::Wx::Menu::Experimental;
		$self->{experimental} = Padre::Wx::Menu::Experimental->new($main);
		$self->wx->Append( $self->experimental->wx, Wx::gettext("E&xperimental") );
	}

	return $self;
}

sub add_alt_n_menu {
	my ($self, $file, $n) = @_;
	#return if $n > 9;

	$self->{alt}->[$n] = $self->{window}->Append(-1, "");
	Wx::Event::EVT_MENU( $self->win, $self->{alt}->[$n], sub { $_[0]->on_nth_pane($n) } );
	$self->update_alt_n_menu($file, $n);

	return;
}

sub update_alt_n_menu {
	my ($self, $file, $n) = @_;
	my $v = $n + 1;

	# TODO: fix the occassional crash here:
	if (not defined $self->{alt}->[$n]) {
		warn "alt-n $n problem ?";
		return;
	}

	#$self->{alt}->[$n]->SetText("$file\tAlt-$v");
	$self->{alt}->[$n]->SetText($file);

	return;
}

sub remove_alt_n_menu {
	my $self = shift;
	$self->{window}->Remove( pop @{ $self->{alt} } );
	return;
}





#####################################################################
# Reflowing the Menu

my @has_document = qw(
	edit_goto
	edit_autocomp
	edit_brace_match
	edit_join_lines
	edit_snippets
	edit_comment_out
	edit_uncomment
	edit_diff
	edit_insert_from_file
);

sub refresh {
	my $self     = shift;
	my $document = Padre::Documents->current;

	if ( _INSTANCE($document, 'Padre::Document::Perl') and $self->wx->GetMenuLabel(3) ne '&Perl') {
		$self->wx->Insert( 3, $self->perl->wx, '&Perl' );
	} elsif ( not _INSTANCE($document, 'Padre::Document::Perl') and $self->wx->GetMenuLabel(3) eq '&Perl') {
		$self->wx->Remove( 3 );
	}

	if ( $document ) {
		my $editor    = $document->editor;
		my $selected  = $editor->GetSelectedText;
		my $selection = !! ( defined $selected and $selected ne '' );

		$self->{$_}->Enable(1) for @has_document;
		$self->{edit_undo}->Enable(  $editor->CanUndo  );
		$self->{edit_redo}->Enable(  $editor->CanRedo  );
		$self->{edit_copy}->Enable(  $selection        );
		$self->{edit_cut}->Enable(   $selection        );
		$self->{edit_paste}->Enable( $editor->CanPaste );
	} else {
		$self->{$_}->Enable(0) for @has_document;
		$self->{$_}->Enable(0) for qw(edit_undo edit_redo edit_copy edit_cut edit_paste);
	}

	# Refresh encapsulated menus
	$self->file->refresh;
	$self->view->refresh;
	$self->run->refresh;
	$self->perl->refresh;
	$self->plugins->refresh;
	$self->help->refresh;
	if ( $self->experimental ) {
		$self->experimental->refresh;
	}

	return 1;
}

sub menu_edit {
	my ( $self, $main ) = @_;
	
	# Create the Edit menu
	my $menu = Wx::Menu->new;

	# Undo/Redo
	$self->{edit_undo} = $menu->Append( Wx::wxID_UNDO, Wx::gettext("&Undo") );
	Wx::Event::EVT_MENU( $main, # Ctrl-Z
		$self->{edit_undo},
		sub { Padre::Documents->current->editor->Undo; },
	);
	$self->{edit_redo} = $menu->Append( Wx::wxID_REDO, Wx::gettext("&Redo") );
	Wx::Event::EVT_MENU( $main, # Ctrl-Y
		$self->{edit_redo},
		sub { Padre::Documents->current->editor->Redo; },
	);
	$menu->AppendSeparator;

	my $menu_edit_select = Wx::Menu->new;
	$menu->Append( -1, Wx::gettext("Select"), $menu_edit_select );
	Wx::Event::EVT_MENU( $main,
		$menu_edit_select->Append( Wx::wxID_SELECTALL, Wx::gettext("Select all\tCtrl-A") ),
		sub { \&Padre::Wx::Editor::text_select_all(@_) },
	);
	$menu_edit_select->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$menu_edit_select->Append( -1, Wx::gettext("Mark selection start\tCtrl-[") ),
		sub {
			my $editor = Padre->ide->wx->main_window->selected_editor or return;
			$editor->text_selection_mark_start;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$menu_edit_select->Append( -1, Wx::gettext("Mark selection end\tCtrl-]") ),
		sub {
			my $editor = Padre->ide->wx->main_window->selected_editor or return;
			$editor->text_selection_mark_end;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$menu_edit_select->Append( -1, Wx::gettext("Clear selection marks") ),
		\&Padre::Wx::Editor::text_selection_clear_marks,
	);


	$self->{edit_copy} = $menu->Append( Wx::wxID_COPY, Wx::gettext("&Copy\tCtrl-C") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_copy},
		sub { Padre->ide->wx->main_window->selected_editor->Copy; }
	);
	$self->{edit_cut} = $menu->Append( Wx::wxID_CUT, Wx::gettext("Cu&t\tCtrl-X") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_cut},
		sub { Padre->ide->wx->main_window->selected_editor->Cut; }
	);
	$self->{edit_paste} = $menu->Append( Wx::wxID_PASTE, Wx::gettext("&Paste\tCtrl-V") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_paste},
		sub { 
			my $editor = Padre->ide->wx->main_window->selected_editor or return;
			$editor->Paste;
		},
	);
	$menu->AppendSeparator;

	Wx::Event::EVT_MENU( $main,
		$menu->Append( Wx::wxID_FIND, Wx::gettext("&Find\tCtrl-F") ),
		sub { Padre::Wx::Dialog::Find->find(@_) },
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("Find Next\tF3") ),
		sub { Padre::Wx::Dialog::Find->find_next(@_) },
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("Find Previous\tShift-F3") ),
		sub { Padre::Wx::Dialog::Find->find_previous(@_) },
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("Ac&k") ),
		\&Padre::Wx::Ack::on_ack,
	);
	$self->{edit_goto} = $menu->Append( -1, Wx::gettext("&Goto\tCtrl-G") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_goto},
		\&Padre::Wx::MainWindow::on_goto,
	);
	$self->{edit_autocomp} = $menu->Append( -1, Wx::gettext("&AutoComp\tCtrl-P") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_autocomp},
		\&Padre::Wx::MainWindow::on_autocompletition,
	);
	$self->{edit_brace_match} = $menu->Append( -1, Wx::gettext("&Brace matching\tCtrl-1") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_brace_match},
		\&Padre::Wx::MainWindow::on_brace_matching,
	);
	$self->{edit_join_lines} = $menu->Append( -1, Wx::gettext("&Join lines\tCtrl-J") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_join_lines},
		\&Padre::Wx::MainWindow::on_join_lines,
	);
	$self->{edit_snippets} = $menu->Append( -1, Wx::gettext("Snippets\tCtrl-Shift-A") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_snippets},
		sub { Padre::Wx::Dialog::Snippets->snippets(@_) },
	); 
	$menu->AppendSeparator;

	# Commenting
	$self->{edit_comment_out} = $menu->Append( -1, Wx::gettext("&Comment Selected Lines\tCtrl-M") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_comment_out},
		\&Padre::Wx::MainWindow::on_comment_out_block,
	);
	$self->{edit_uncomment} = $menu->Append( -1, Wx::gettext("&Uncomment Selected Lines\tCtrl-Shift-M") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_uncomment},
		\&Padre::Wx::MainWindow::on_uncomment_block,
	);
	$menu->AppendSeparator;

	# Tab And Space
	my $menu_edit_tab = Wx::Menu->new;
	$menu->Append( -1, Wx::gettext("Tabs and Spaces"), $menu_edit_tab );
	Wx::Event::EVT_MENU( $main,
		$menu_edit_tab->Append( -1, Wx::gettext("Tabs to Spaces...") ),
		sub { $_[0]->on_tab_and_space('Tab_to_Space') },
	);
	Wx::Event::EVT_MENU( $main,
		$menu_edit_tab->Append( -1, Wx::gettext("Spaces to Tabs...") ),
		sub { $_[0]->on_tab_and_space('Space_to_Tab') },
	);
	Wx::Event::EVT_MENU( $main,
		$menu_edit_tab->Append( -1, Wx::gettext("Delete Trailing Spaces") ),
		sub { $_[0]->on_delete_ending_space() },
	);
	Wx::Event::EVT_MENU( $main,
		$menu_edit_tab->Append( -1, Wx::gettext("Delete Leading Spaces") ),
		sub { $_[0]->on_delete_leading_space() },
	);

	# Upper and Lower Case
	my $menu_edit_case = Wx::Menu->new;
	$menu->Append( -1, Wx::gettext("Upper/Lower Case"), $menu_edit_case );
	Wx::Event::EVT_MENU( $main,
		$menu_edit_case->Append( -1, Wx::gettext("Upper All\tCtrl-Shift-U") ),
		sub { Padre::Documents->current->editor->UpperCase; },
	);
	Wx::Event::EVT_MENU( $main,
		$menu_edit_case->Append( -1, Wx::gettext("Lower All\tCtrl-U") ),
		sub { Padre::Documents->current->editor->LowerCase; },
	);
	$menu->AppendSeparator;

	# Diff
	$self->{edit_diff} = $menu->Append( -1, Wx::gettext("Diff") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_diff},
		\&Padre::Wx::MainWindow::on_diff,
	);
	$self->{edit_insert_from_file} = $menu->Append( -1, Wx::gettext("Insert From File...") );
	Wx::Event::EVT_MENU( $main,
		$self->{edit_insert_from_file},
		\&Padre::Wx::MainWindow::on_insert_from_file,
	);
	$menu->AppendSeparator;

	# User Preferences
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("Preferences") ),
		\&Padre::Wx::MainWindow::on_preferences,
	);
	
	return $menu;
}

sub menu_window {
	my ( $self, $main ) = @_;
	
	# Create the window menu
	my $menu = Wx::Menu->new;
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("&Split window") ),
		\&Padre::Wx::MainWindow::on_split_window,
	);
	$menu->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$menu->Append(-1, Wx::gettext("Next File\tCtrl-TAB")),
		\&Padre::Wx::MainWindow::on_next_pane,
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append(-1, Wx::gettext("Previous File\tCtrl-Shift-TAB")),
		\&Padre::Wx::MainWindow::on_prev_pane,
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append(-1, Wx::gettext("Last Visited File\tCtrl-6")),
		\&Padre::Wx::MainWindow::on_last_visited_pane,
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append(-1, Wx::gettext("Right Click\tAlt-/")),
		sub {
			my $editor = $_[0]->selected_editor;
			if ($editor) {
				$editor->on_right_down($_[1]);
			}
		},
	);
	$menu->AppendSeparator;


	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("GoTo Subs Window\tAlt-S") ),
		sub {
			$_[0]->{subs_panel_was_closed} = ! Padre->ide->config->{main_subs_panel};
			$_[0]->show_functions(1); 
			$_[0]->{gui}->{subs_panel}->SetFocus;
		},
	); 
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("GoTo Output Window\tAlt-O") ),
		sub {
			$_[0]->show_output(1);
			$_[0]->{gui}->{output_panel}->SetFocus;
		},
	);
	$self->{window_goto_syntax_check} = $menu->Append( -1, Wx::gettext("GoTo Syntax Check Window\tAlt-C") );
	Wx::Event::EVT_MENU( $main,
		$self->{window_goto_syntax_check},
		sub {
			$_[0]->show_syntaxbar(1);
			$_[0]->{gui}->{syntaxcheck_panel}->SetFocus;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("GoTo Main Window\tAlt-M") ),
		sub {
			$_[0]->selected_editor->SetFocus;
		},
	); 
	$menu->AppendSeparator;
	
	return $menu;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
