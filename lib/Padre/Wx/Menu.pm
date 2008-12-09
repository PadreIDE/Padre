package Padre::Wx::Menu;

use 5.008;
use strict;
use warnings;
use Params::Util             qw{_INSTANCE};
use Padre::Util              ();
use Padre::Wx                ();
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
		# upgraded to be FULLY encapsulated classes.
		perl         => 'perl',
		run          => 'run',
		plugins      => 'plugins',
		help         => 'help',
		experimental => 'experimental',
	};

sub new {
	my $class        = shift;
	my $main         = shift;
	my $config       = Padre->ide->config;
	my $experimental = $config->{experimental};

	# Generate the individual menus
	my $self         = bless {}, $class;
	$self->{win}     = $main;
	$self->{file}    = $self->menu_file( $main );
	$self->{edit}    = $self->menu_edit( $main );
	$self->{view}    = $self->menu_view( $main );
	$self->{perl}    = Padre::Wx::Menu::Perl->new($main);
	$self->{run}     = Padre::Wx::Menu::Run->new($main);
	$self->{plugins} = Padre::Wx::Menu::Plugins->new($main);
	$self->{window}  = $self->menu_window( $main );
	$self->{help}    = Padre::Wx::Menu::Help->new($main);

	# Generate the final menubar
	$self->{wx} = Wx::MenuBar->new;
	$self->wx->Append( $self->{file},      Wx::gettext("&File")    );
	$self->wx->Append( $self->{edit},      Wx::gettext("&Edit")    );
	$self->wx->Append( $self->{view},      Wx::gettext("&View")    );
	$self->wx->Append( $self->run->wx,     Wx::gettext("&Run")     );
	$self->wx->Append( $self->plugins->wx, Wx::gettext("Pl&ugins") );
	$self->wx->Append( $self->{window},    Wx::gettext("&Window")  );
	$self->wx->Append( $self->help->wx,    Wx::gettext("&Help")    );

	if ( $experimental ) {
		# Create the Experimental menu
		# All the crap that doesn't work, have a home,
		# or should never be seen be real users goes here.
		require Padre::Wx::Menu::Experimental;
		$self->{experimental} = Padre::Wx::Menu::Experimental->new($main);
		$self->wx->Append( $self->experimental->wx, Wx::gettext("E&xperimental") );
	}

	# Setup menu state from configuration
	$self->{view_lines}->Check( $config->{editor_linenumbers} ? 1 : 0 );
	$self->{view_folding}->Check( $config->{editor_codefolding} ? 1 : 0 );
	$self->{view_currentlinebackground}->Check( $config->{editor_currentlinebackground} ? 1 : 0 );
	$self->{view_eol}->Check( $config->{editor_eol} ? 1 : 0 );
	$self->{view_whitespaces}->Check( $config->{editor_whitespaces} ? 1 : 0 );
	unless ( Padre::Util::WIN32 ) {
		$self->{view_statusbar}->Check( $config->{main_statusbar} ? 1 : 0 );
	}
	$self->{view_output}->Check( $config->{main_output_panel} ? 1 : 0 );
	$self->{view_functions}->Check( $config->{main_subs_panel} ? 1 : 0 );
	$self->{view_indentation_guide}->Check( $config->{editor_indentationguides} ? 1 : 0 );
	$self->{view_show_calltips}->Check( $config->{editor_calltips} ? 1 : 0 );
	$self->{view_show_syntaxcheck}->Check( $config->{editor_syntaxcheck} ? 1 : 0 );

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
	file_close
	file_close_all
	file_close_all_but_current
	file_reload_file
	file_save
	file_save_as
	file_save_all
	file_convert_nl_windows
	file_convert_nl_unix
	file_convert_nl_mac
	file_docstat
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
		my $editor = $document->editor;
		# check "wrap lines"
		my $mode = $editor->GetWrapMode;
		my $is_vwl_checked = $self->{view_word_wrap}->IsChecked;
		if ( $mode eq Wx::wxSTC_WRAP_WORD and not $is_vwl_checked ) {
			$self->{view_word_wrap}->Check(1);
		} elsif ( $mode eq Wx::wxSTC_WRAP_NONE and $is_vwl_checked ) {
			$self->{view_word_wrap}->Check(0);
		}

		my $selection_exists = 0;
		my $txt = $editor->GetSelectedText;
		if ( defined($txt) && length($txt) > 0 ) {
			$selection_exists = 1;
		}

		$self->{$_}->Enable(1) for @has_document;
		$self->{edit_undo}->Enable(  $editor->CanUndo  );
		$self->{edit_redo}->Enable(  $editor->CanRedo  );
		$self->{edit_copy}->Enable(  $selection_exists );
		$self->{edit_cut}->Enable(   $selection_exists );
		$self->{edit_paste}->Enable( $editor->CanPaste );
	} else {
		$self->{$_}->Enable(0) for @has_document;
		$self->{$_}->Enable(0) for qw(edit_undo edit_redo edit_copy edit_cut edit_paste);
	}

	# Refresh submenus
	$self->run->refresh;
	$self->perl->refresh;
	$self->plugins->refresh;
	$self->help->refresh;

	return 1;
}

sub menu_file {
	my ( $self, $main ) = @_;

	# Create the File menu
	my $menu = Wx::Menu->new;

	# Creating new things
	Wx::Event::EVT_MENU( $main,
		$menu->Append( Wx::wxID_NEW, Wx::gettext("&New\tCtrl-N") ),
		\&Padre::Wx::MainWindow::on_new,
	);
	my $menu_file_new = Wx::Menu->new;
	$menu->Append( -1, Wx::gettext("New..."), $menu_file_new );
	Wx::Event::EVT_MENU( $main,
		$menu_file_new->Append( -1, Wx::gettext('Perl Distribution (Module::Starter)') ),
		sub { Padre::Wx::Dialog::ModuleStart->start(@_) },
	);

	# Opening and closing files
	Wx::Event::EVT_MENU( $main,
		$menu->Append( Wx::wxID_OPEN, Wx::gettext("&Open...\tCtrl-O") ),
		sub { $_[0]->on_open },
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("Open Selection\tCtrl-Shift-O") ),
		sub { $_[0]->on_open_selection },
	);
	
	$self->{file_close} = $menu->Append( Wx::wxID_CLOSE, Wx::gettext("&Close\tCtrl-W") );
	Wx::Event::EVT_MENU( $main,
		$self->{file_close},
		sub { $_[0]->on_close },
	);
	
	$self->{file_close_all} = $menu->Append( -1, Wx::gettext('Close All') );
	Wx::Event::EVT_MENU( $main,
		$self->{file_close_all},
		sub { $_[0]->on_close_all },
	);
	$self->{file_close_all_but_current}
		= $menu->Append( -1, Wx::gettext('Close All but Current Document') );
	Wx::Event::EVT_MENU( $main,
		$self->{file_close_all_but_current},
		sub { $_[0]->on_close_all_but_current },
	);
	$self->{file_reload_file} = $menu->Append( -1, Wx::gettext('Reload file') );
	Wx::Event::EVT_MENU( $main,
		$self->{file_reload_file},
		sub { $_[0]->on_reload_file },
	);
	$menu->AppendSeparator;

	# Saving
	$self->{file_save} = $menu->Append( Wx::wxID_SAVE, Wx::gettext("&Save\tCtrl-S") );
	Wx::Event::EVT_MENU( $main,
		$self->{file_save},
		sub { $_[0]->on_save },
	);
	$self->{file_save_as} = $menu->Append( Wx::wxID_SAVEAS, Wx::gettext('Save &As...') );
	Wx::Event::EVT_MENU( $main,
		$self->{file_save_as},
		sub { $_[0]->on_save_as },
	);
	$self->{file_save_all} = $menu->Append( -1, Wx::gettext('Save All') );
	Wx::Event::EVT_MENU( $main,
		$self->{file_save_all},
		sub { $_[0]->on_save_all },
	);
	$menu->AppendSeparator;

#	# Printing
	$self->{file_print} = $menu->Append( Wx::wxID_PRINT, Wx::gettext('&Print...') );
	Wx::Event::EVT_MENU( $main,
		$self->{file_print},
		sub { Padre::Wx::Print::OnPrint(@_) }     
	);                                                                            
	$menu->AppendSeparator;

	# Conversions and Transforms
	$self->{file_convert_nl} = Wx::Menu->new;
	$menu->Append( -1, Wx::gettext("Convert..."), $self->{file_convert_nl} );
	$self->{file_convert_nl_windows} = $self->{file_convert_nl}->Append(-1, Wx::gettext("EOL to Windows"));
	Wx::Event::EVT_MENU( $main,
		$self->{file_convert_nl_windows},
		sub { $_[0]->convert_to("WIN") },
	);
	$self->{file_convert_nl_unix} = $self->{file_convert_nl}->Append(-1, Wx::gettext("EOL to Unix"));
	Wx::Event::EVT_MENU( $main,
		$self->{file_convert_nl_unix},
		sub { $_[0]->convert_to("UNIX") },
	);
	$self->{file_convert_nl_mac} = $self->{file_convert_nl}->Append(-1, Wx::gettext("EOL to Mac Classic"));
	Wx::Event::EVT_MENU( $main,
		$self->{file_convert_nl_mac},
		sub { $_[0]->convert_to("MAC") },
	);
	$menu->AppendSeparator;

	# Recent things
	$self->{file_recentfiles} = Wx::Menu->new;
	$menu->Append( -1, Wx::gettext("&Recent Files"), $self->{file_recentfiles} );
	Wx::Event::EVT_MENU( $main,
		$self->{file_recentfiles}->Append(-1, Wx::gettext("Open All Recent Files")),
		sub { $_[0]->on_open_all_recent_files },
	);
	Wx::Event::EVT_MENU( $main,
		$self->{file_recentfiles}->Append(-1, Wx::gettext("Clean Recent Files List")),
		sub {
			Padre::DB->delete_recent( 'files' );
			# replace the whole File menu
			my $menu = $_[0]->{menu}->menu_file($_[0]);
			my $menu_place = $_[0]->{menu}->wx->FindMenu( Wx::gettext("&File") );
			$_[0]->{menu}->wx->Replace( $menu_place, $menu, Wx::gettext("&File") );
		},
	);
	$self->{file_recentfiles}->AppendSeparator;
	my $idx;
	foreach my $f ( Padre::DB->get_recent_files ) {
		next unless -f $f;
		++$idx;
		Wx::Event::EVT_MENU( $main,
			$self->{file_recentfiles}->Append(-1, $idx < 10 ? "&$idx. $f" : "$idx. $f"), 
			sub { $_[0]->setup_editors($f); },
		);
	}
	$menu->AppendSeparator;
	
	# Word Stats
	$self->{file_docstat} = $menu->Append( -1, Wx::gettext('Doc Stats') );
	Wx::Event::EVT_MENU( $main,
		$self->{file_docstat},
		sub { $_[0]->on_doc_stats },
	);
	$menu->AppendSeparator;

	# Exiting
	Wx::Event::EVT_MENU( $main,
		$menu->Append( Wx::wxID_EXIT, Wx::gettext("&Quit\tCtrl-Q") ),
		sub { $_[0]->Close },
	);
	
	return $menu;
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

sub menu_view {
	my ( $self, $main ) = @_;
	
	my $config = Padre->ide->config;
	
	# Create the View menu
	my $menu_view = Wx::Menu->new;

	# GUI Elements
	$self->{view_output} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Output") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_output},
		sub {
			$_[0]->show_output(
				$_[0]->{menu}->{view_output}->IsChecked
			),
		},
	);
	$self->{view_functions} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Functions") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_functions},
		sub {
			$_[0]->show_functions(
				$_[0]->{menu}->{view_functions}->IsChecked
			),
		},
	);
	unless ( Padre::Util::WIN32 ) {
		# On Windows disabling the status bar is broken, so don't allow it
		$self->{view_statusbar} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show StatusBar") );
		Wx::Event::EVT_MENU( $main,
			$self->{view_statusbar},
			\&Padre::Wx::MainWindow::on_toggle_status_bar,
		);
	}
	$menu_view->AppendSeparator;

	# Editor look and feel
	$self->{view_lines} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Line numbers") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_lines},
		\&Padre::Wx::MainWindow::on_toggle_line_numbers,
	);
	$self->{view_folding} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Code Folding") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_folding},
		\&Padre::Wx::MainWindow::on_toggle_code_folding,
	);
	$self->{view_eol} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Newlines") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_eol},
		\&Padre::Wx::MainWindow::on_toggle_eol,
	);
	$self->{view_whitespaces} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Whitespaces") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_whitespaces},
		\&Padre::Wx::MainWindow::on_toggle_whitespaces,
	);

	$self->{view_indentation_guide} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Indentation Guide") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_indentation_guide},
		\&Padre::Wx::MainWindow::on_toggle_indentation_guide,
	);
	$menu_view->AppendSeparator;	

	$self->{view_show_calltips} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Call Tips") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_show_calltips},
		sub { $config->{editor_calltips} = $self->{view_show_calltips}->IsChecked },
	);
	$self->{view_show_syntaxcheck} = $menu_view->AppendCheckItem( -1, Wx::gettext("Show Syntax Check") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_show_syntaxcheck},
		\&Padre::Wx::MainWindow::on_toggle_syntax_check,
	);
	$menu_view->AppendSeparator;
	
	$self->{view_word_wrap} = $menu_view->AppendCheckItem( -1, Wx::gettext("Word-Wrap") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_word_wrap},
		sub {
			$_[0]->on_word_wrap(
				$_[0]->{menu}->{view_word_wrap}->IsChecked
			),
		},
	);
	$self->{view_currentlinebackground} = $menu_view->AppendCheckItem( -1, Wx::gettext("Highlight Current Line") );
	Wx::Event::EVT_MENU( $main,
		$self->{view_currentlinebackground},
		\&Padre::Wx::MainWindow::on_toggle_current_line_background,
	);
	$menu_view->AppendSeparator;

	Wx::Event::EVT_MENU( $main,
		$menu_view->Append( -1, Wx::gettext("Increase Font Size\tCtrl-+") ),
		sub { $_[0]->zoom(+1) },
	);
	Wx::Event::EVT_MENU( $main,
		$menu_view->Append( -1, Wx::gettext("Decrease Font Size\tCtrl--") ),
		sub { $_[0]->zoom(-1) },
	);
	Wx::Event::EVT_MENU( $main,
		$menu_view->Append( -1, Wx::gettext("Reset Font Size\tCtrl-/") ),
		sub { $_[0]->zoom( -1 * $_[0]->selected_editor->GetZoom ) },
	);

	$menu_view->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$menu_view->Append( -1, Wx::gettext("Set Bookmark\tCtrl-B") ),
		sub { Padre::Wx::Dialog::Bookmarks->set_bookmark($_[0]) },
	);
	Wx::Event::EVT_MENU( $main,
		$menu_view->Append( -1, Wx::gettext("Goto Bookmark\tCtrl-Shift-B") ),
		sub { Padre::Wx::Dialog::Bookmarks->goto_bookmark($_[0]) },
	);

	$menu_view->AppendSeparator;
	$self->{view_language} = Wx::Menu->new;
	$menu_view->Append( -1, Wx::gettext("Language"), $self->{view_language} );
	
	Wx::Event::EVT_MENU( $main,
		$self->{view_language}->AppendRadioItem( -1, Wx::gettext("System Default") ),
		sub { $_[0]->change_locale() },
	);
	$self->{view_language}->AppendSeparator;
	my %languages = Padre::Locale::languages;
	foreach my $name (sort { $languages{$a} cmp $languages{$b} }  keys %languages) {
		my $label = $languages{$name};
		if ( $label eq 'English' ) {
			$label = "English (The Queen's)";
		}
		my $item = $self->{view_language}->AppendRadioItem( -1, $label );
		Wx::Event::EVT_MENU( $main,
			$item,
			sub { $_[0]->change_locale($name) },
		);
		if ($config->{host}->{locale} and $config->{host}->{locale} eq $name) {
			$item->Check(1);
		}
	}

	$menu_view->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$menu_view->Append( -1, Wx::gettext("&Full screen\tF11") ),
		\&Padre::Wx::MainWindow::on_full_screen,
	);

	return $menu_view;
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
