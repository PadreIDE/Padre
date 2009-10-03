#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	if ( $^O eq 'MSWin32' ) {
		plan skip_all => 'Windows currently has problems with Unicode files';
		exit(0);
	}

	# Ticket #643
	plan( skip_all => 'Sometimes fails for unknown reasons, skipping for release till fixed' );
	exit 0;
}

use File::Basename qw(basename);
use File::Copy qw(copy);
use File::Spec::Functions qw(catfile);
use Test::NoWarnings;
use Test::Builder;
use t::lib::Padre;
use Cwd;
use Padre;

plan tests => 100;
diag "PADRE_HOME: $ENV{PADRE_HOME}";
my $home = $ENV{PADRE_HOME};
copy catfile( 'eg', 'hello_world.pl' ),   catfile( $home, 'hello_world.pl' );
copy catfile( 'eg', 'cyrillic_test.pl' ), catfile( $home, 'cyrillic_test.pl' );

copy catfile( 't', 'files', 'one_char.pl' ), catfile( $home, 'one_char.pl' );

my $padreInstance = Padre->new;
my $ide           = Padre->ide;
my $frame         = $ide->wx->main;

diag "This test script is known to fail sometimes on some operating systems";
diag "If this happens to you, please report it to the Padre developers";
diag "and use the force to install Padre anyway.";

my @events = (
	{   delay => 1000, # TODO: if we reduce this to 100 or even 500 the test crashes (segfault?) after 2 oks
		               # this seems to be an issue with Padre or wx beneath but for now we hide it with the larger
		               # delay
		code  => sub {
			my $main = $ide->wx->main;
			my $T    = Test::Builder->new;
			SCOPE: {
				my @editors = $main->editors;
				$T->is_num( scalar(@editors), 1, '1 editor' );
			}
			$main->setup_editors( catfile( $home, 'hello_world.pl' ) );
			SCOPE: {
				my @editors = $main->editors;

				#$T->todo_skip('close the empty buffer');
				$T->is_num( scalar(@editors), 1, '1 editor' );
			}
		},
	},
	{   delay => 100,
		code  => sub {
			my $main   = $ide->wx->main;
			my $doc    = $main->current->document;
			my $editor = $doc->editor;
			$editor->SetSelection( 10, 15 );
			my $T = Test::Builder->new;
			$T->is_eq( $editor->GetSelectedText, '/perl', 'selection' );
			$T->is_eq( $main->current->text,     '/perl', 'selected_text' );

			$editor->ReplaceSelection('/java');
			$editor->SetSelection( 0, 0 );
			$T->is_eq( $main->current->text, '', 'no selected_text' );

			# Search for 'java'
			Padre::DB::History->create(
				type => 'search',
				name => 'java',
			);
			$main->find->search;

			my ( $start, $end ) = $editor->GetSelection;
			$T->is_num( $start, 11, 'start is 11' );
			$T->is_num( $end,   15, 'end is 15' );

			$T->is_eq( $main->current->text, 'java', 'java selected_text' );

			$main->on_save;
			my $line = '';

			# TODO: better report if file could not be opended
			if ( open my $fh, '<', catfile( $home, 'hello_world.pl' ) ) {
				$line = <$fh>;
			} else {
				$T->diag("Could not open hello_world.pl '$!'");
			}
			$T->is_eq( $line, "#!/usr/bin/java\n", 'file really changed' );
			}
	},
	{   delay => 200,
		code  => sub {
			my $main = $ide->wx->main;
			$main->setup_editors( catfile( $home, 'cyrillic_test.pl' ) );

			my $T      = Test::Builder->new;
			my $doc    = $main->current->document;
			my $editor = $doc->editor;

			Padre::DB::History->create(
				type => 'search',
				name => 'test',
			);

			SCOPE: {
				my @editors = $main->editors;
				$T->is_num( scalar(@editors), 2, '2 editors' );
			}
			SCOPE: {
				$main->find->search;
				$T->is_eq( $main->current->text, 'test', 'test selected_text' );
				my ( $start, $end ) = $editor->GetSelection;
				$T->is_num( $start, 56, 'start is 56' );
				$T->is_num( $end,   60, 'end is 60' );
			}
			SCOPE: {
				$main->find->search;
				$T->is_eq( $main->current->text, 'test', 'selected_text' );
				my ( $start, $end ) = $editor->GetSelection;
				$T->is_num( $start, 211, 'start is 211' );
				$T->is_num( $end,   215, 'end is 215' );
			}

			$main->close_all( $main->notebook->GetSelection );
			SCOPE: {
				my @editors = $main->editors;
				$T->is_num( scalar(@editors), 1, '1 editor' );
				my $doc = $main->current->document;
				$T->is_eq( basename( $doc->filename ), 'cyrillic_test.pl', 'filename is cyrillic_test.pl' );
			}
			Padre::Wx::Dialog::Bookmarks->set_bookmark($main);
		},
		subevents => [
			{   delay => 1000,
				code  => sub {
					my $main   = $ide->wx->main;
					my $T      = Test::Builder->new;
					my $dialog = Padre::Wx::Dialog::Bookmarks::get_dialog();
					my $event  = Wx::CommandEvent->new(
						&Wx::wxEVT_COMMAND_BUTTON_CLICKED,
						$dialog->{_widgets_}->{cancel}->GetId
					);

					#$dialog->{_widgets_}->{cancel}->GetEventHandler->ProcessEvent( $event );
					$dialog->GetEventHandler->ProcessEvent($event);

					#$dialog->GetEventHandler->AddPendingEvent( $event );
					#$dialog->EndModal(Wx::wxID_CANCEL);
				},
			},
		],
	},
	{   delay => 200,
		code  => sub {
			my $main = $ide->wx->main;
			my $T    = Test::Builder->new;
			$main->close_all;
			SCOPE: {
				my @editors = $main->editors;
				$T->is_num( scalar(@editors), 0, '0 editor' );
				my $doc = $main->current->document;
				$T->ok( not( defined $doc ), 'no document' );
			}
			Padre::Wx::Dialog::Bookmarks->set_bookmark($main);
		},
	},
	{   delay => 400,
		code  => sub {
			my $T = Test::Builder->new;
			$T->diag("changing locale");
			my $main = $ide->wx->main;
			$main->change_locale('en');
			$main->change_locale('');
			$main->change_locale('en');
		},
	},
	{   delay => 200,
		code  => sub {
			my $T = Test::Builder->new;
			$T->diag("setting syntax check");
			my $main = $ide->wx->main;
			$T->diag( "syntaxcheck_panel: " . $main->syntax );
			$main->menu->view->{show_syntaxcheck}->Check(1);
			$main->on_toggle_syntax_check( event( checked => 1 ) );
			$T->ok( $main->syntax->isa('Wx::ListView'), 'is a Wx::ListView' );
		},
	},
	{

		# for now, just check if there are no warnings generated
		delay => 800,
		code  => sub {
			my $T    = Test::Builder->new;
			my $main = $ide->wx->main;
			$T->diag("setup editor for one_char.pl");
			$main->setup_editors( catfile( $home, 'one_char.pl' ) );
			my @editors = $main->editors;
			$T->is_num( scalar(@editors), 1, '1 editor' );
		},
	},
	{

		# for now, just check if there are no warnings generated
		delay => 1500,
		code  => sub {
			my $T    = Test::Builder->new;
			my $main = $ide->wx->main;
			$T->diag("setup editor for cyrillic_test.pl");
			$main->setup_editors( catfile( $home, 'cyrillic_test.pl' ) );
			my @editors = $main->editors;
			$T->is_num( scalar(@editors), 2, '2 editor' );
		},
	},
	{   delay => 800,
		code  => sub {
			my $T    = Test::Builder->new;
			my $main = $ide->wx->main;
			$main->close_all;
			$T->diag("create a new editor");
			$main->on_new();
			my @editors = $main->pages;
			$T->is_num( scalar(@editors), 1, 'one new editor' );
			my $doc    = $main->current->document;
			my $editor = $doc->editor;
			SCOPE: {

				#one abs path file.
				my $path = catfile( $home, 'cyrillic_test.pl' );
				$doc->text_set($path);
				$editor->SetSelection( 0, length($path) );
				$main->on_open_selection();
				$T->is_num( scalar( $main->pages ), 2, 'new and abs cyrillic_test open' );

			}
			$main->on_close();
			$T->is_num( scalar( $main->pages ), 1, 'back to unsaved?' );
			SCOPE: {

				#put down one filename that is relative to the dir padre was started from
				my $path = catfile( './eg/perl5/', 'cyrillic_test.pl' );
				$doc->text_set($path);
				$editor->SetSelection( 0, length($path) );
				$main->on_open_selection();
				$T->is_num( scalar( $main->pages ), 2, 'new and relative cyrillic_test open' );
			}
			$main->on_close();
			$T->is_num( scalar( $main->pages ), 1, 'back to unsaved?' );
			SCOPE: {

				#put down one filename that is relative to the dir padre was started from
				my $path = catfile( './eg/perl5/', 'cyrillic_test.pl' ) . "\n";
				$doc->text_set($path);
				$editor->SetSelection( 0, length($path) );
				$main->on_open_selection();
				$T->is_num( scalar( $main->pages ), 2, 'relative cyrillic_test open with additional \n' );
			}
			$main->on_close();
			$T->is_num( scalar( $main->pages ), 1, 'back to unsaved?' );
			SCOPE: {

				#put down one filename that is relative to the dir padre was started from
				my $path = "\n" . catfile( './eg/perl5/', 'cyrillic_test.pl' ) . "\n";
				$doc->text_set($path);
				$editor->SetSelection( 0, length($path) );
				$main->on_open_selection();
				$T->is_num( scalar( $main->pages ), 2, 'relative cyrillic_test open with additional \n' );
			}
			$main->on_close();
			$T->is_num( scalar( $main->pages ), 1, 'back to unsaved?' );
			SCOPE: {

				#put down one filename that is relative to the dir padre was started from
				#$T->diag(Cwd::cwd());
				my $path = "\t   " . catfile( './eg/perl5/', 'cyrillic_test.pl' ) . " \n\t ";
				$doc->text_set($path);
				$editor->SetSelection( 0, length($path) );

				#$T->diag("selected : ".$main->current->text);
				$main->on_open_selection();
				$T->is_num( scalar( $main->pages ), 2, 'relative cyrillic_test open with additional \n' );
			}

			#redo above tests from an editor which _does_ have a filename (ie, has been opened or saved, not newly created

			#several files
			#non .pm file
			#abs path
			#use line
			#require line
			#multiple use/require lines
			#makefile
			#no selection, fill in - not there, popup again with edit and possibly options to choose from
			#selection isn't there, but found similar?

		},
	},
	{   delay => 4000,
		code  => sub {
			my $T = Test::Builder->new;
			$T->diag("exiting");
			$ide->wx->ExitMainLoop;
			$ide->wx->main->Destroy;
		},
	},
);

t::lib::Padre::setup_event( $frame, \@events, 0 );

$ide->wx->MainLoop;

ok( 1, 'finished' );
BEGIN { $tests += 1; }

sub event {
	my (%args) = @_;
	return bless \%args, 'Wx::Event';
}

package Wx::Event;

sub IsChecked {
	$_[0]->{checked};
}
