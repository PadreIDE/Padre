#!/usr/bin/perl

use strict;
use warnings;
#use Test::NeedsDisplay ':skip_all';
use Test::More;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}
BEGIN {
	if ( $^O eq 'MSWin32' ) {
		plan skip_all => 'Windows currently has problems with Unicode files';
		exit(0);
	}
}

use File::Basename        qw(basename);
use File::Copy            qw(copy);
use File::Spec::Functions qw(catfile);
use Test::NoWarnings;
use Test::Builder;
use t::lib::Padre;
use Padre;

our $tests;

plan tests => $tests+1;
diag "PADRE_HOME: $ENV{PADRE_HOME}";
my $home = $ENV{PADRE_HOME};
copy catfile('eg', 'hello_world.pl'),    catfile($home, 'hello_world.pl');
copy catfile('eg', 'cyrillic_test.pl'),  catfile($home, 'cyrillic_test.pl');

copy catfile('t', 'files', 'one_char.pl'),  catfile($home, 'one_char.pl');

my $ide   = Padre->ide;
my $frame = $ide->wx->main;

my @events = (
	{
		delay => 1000,   # TODO: if we reduce this to 100 or even 500 the test crashes (segfault?) after 2 oks
		                 # this seems to be an issue with Padre or wx beneath but for now we hide it with the larger
		                 # delay
		code  => sub {
			my $main = $ide->wx->main;
			my $T = Test::Builder->new;
			{
				my @editors = $main->pages;
				$T->is_num(scalar(@editors), 1, '1 editor');
			}
			$main->setup_editors( catfile($home, 'hello_world.pl') );
			{
				my @editors = $main->pages;
				#$T->todo_skip('close the empty buffer');
				$T->is_num(scalar(@editors), 1, '1 editor');
			}
			BEGIN { $main::tests += 2; }
		},
	},
	{
		delay => 100,
		code  => sub {
			my $main = $ide->wx->main;
			my $doc  = $main->current->document;
			my $editor = $doc->editor;
			$editor->SetSelection(10, 15);
			my $T = Test::Builder->new;
			$T->is_eq($editor->GetSelectedText, '/perl', 'selection');
			$T->is_eq($main->current->text,     '/perl', 'selected_text');

			$editor->ReplaceSelection('/java');
			$editor->SetSelection(0, 0);
			$T->is_eq($main->current->text,     '', 'no selected_text');

			Padre::Wx::Dialog::Find->search( search_term => qr/java/ );
			my ($start, $end) = $editor->GetSelection;
			$T->is_num($start, 11, 'start is 11');
			$T->is_num($end,   15, 'end is 15');
			
			$T->is_eq($main->current->text,     'java', 'java selected_text');

			$main->on_save;
			my $line = '';
			# TODO: better report if file could not be opended
			if ( open my $fh, '<', catfile($home, 'hello_world.pl') ) {
				$line = <$fh>;
			} else {
				$T->diag("Could not open hello_world.pl '$!'");
			}
			$T->is_eq($line, "#!/usr/bin/java\n", 'file really changed');

			BEGIN { $main::tests += 7; }
		}
	},
	{
		delay => 200,
		code  => sub {
			my $main = $ide->wx->main;
			$main->setup_editors( catfile($home, 'cyrillic_test.pl') );

			my $T = Test::Builder->new;
			my $doc  = $main->current->document;
			my $editor = $doc->editor;

			{
				my @editors = $main->pages;
				$T->is_num(scalar(@editors), 2, '2 editors');
			}

			{
				Padre::Wx::Dialog::Find->search( search_term => qr/test/ );
				$T->is_eq($main->current->text,    'test', 'test selected_text');
				my ($start, $end) = $editor->GetSelection;
				$T->is_num($start, 56, 'start is 56');
				$T->is_num($end,   60, 'end is 60');
			}
			{
				Padre::Wx::Dialog::Find->search( search_term => qr/test/ );
				$T->is_eq($main->current->text,    'test', 'selected_text');
				my ($start, $end) = $editor->GetSelection;
				$T->is_num($start, 211, 'start is 211');
				$T->is_num($end,   215, 'end is 215');
			}

			$main->on_close_all_but_current;
			{
				my @editors = $main->pages;
				$T->is_num(scalar(@editors), 1, '1 editor');
				my $doc = $main->current->document;
				$T->is_eq(basename($doc->filename), 'cyrillic_test.pl', 'filename is cyrillic_test.pl');
			}
			Padre::Wx::Dialog::Bookmarks->set_bookmark($main);

			BEGIN { $main::tests += 9; }
		},
		subevents => [
			{
			delay => 1000,
			code  => sub {
				my $main = $ide->wx->main;
				my $T = Test::Builder->new;
				my $dialog = Padre::Wx::Dialog::Bookmarks::get_dialog();
				my $event = Wx::CommandEvent->new( &Wx::wxEVT_COMMAND_BUTTON_CLICKED, $dialog->{_widgets_}->{cancel}->GetId );
				#$dialog->{_widgets_}->{cancel}->GetEventHandler->ProcessEvent( $event );
				$dialog->GetEventHandler->ProcessEvent( $event );
				#$dialog->GetEventHandler->AddPendingEvent( $event );
				#$dialog->EndModal(Wx::wxID_CANCEL);
				BEGIN { $main::tests += 0; }
			},
		},
		],
	},
	{
		delay => 200,
		code  => sub {
			my $main = $ide->wx->main;
			my $T = Test::Builder->new;
			$main->on_close_all;
			{
				my @editors = $main->pages;
				$T->is_num(scalar(@editors), 0, '0 editor');
				my $doc = $main->current->document;
				$T->ok(not(defined $doc), 'no document');
			}
			Padre::Wx::Dialog::Bookmarks->set_bookmark($main);
			BEGIN { $main::tests += 2; }
		},
	},
	{
		delay => 400,
		code  => sub {
			my $T = Test::Builder->new;
			$T->diag("changing locale");
			my $main = $ide->wx->main;
			$main->change_locale('en');
			$main->change_locale('');
			$main->change_locale('en');
			BEGIN { $main::tests += 0; }
		},
	},
	{
		delay => 200,
		code  => sub {
			my $T = Test::Builder->new;
			$T->diag("setting syntax check");
			my $main = $ide->wx->main;
			$T->diag("syntaxcheck_panel: $main->{gui}->{syntaxcheck_panel}");
			#$T->ok(not (defined $main->{gui}->{syntaxcheck_panel}), 'syntaxcheck_panel is not yet defined');
			$main->menu->view->{show_syntaxcheck}->Check(1);
			$main->on_toggle_syntax_check(event(checked => 1));
			$T->ok($main->{gui}->{syntaxcheck_panel}->isa('Wx::ListView'), 'is a Wx::ListView');
			BEGIN { $main::tests += 1; }
		},
	},
	{
		# for now, just check if there are no warnings generated
		delay => 800,
		code  => sub {
			my $T = Test::Builder->new;
			my $main = $ide->wx->main;
			$T->diag("setup editor for one_char.pl");
			$main->setup_editors( catfile($home, 'one_char.pl') );
			my @editors = $main->pages;
			$T->is_num(scalar(@editors), 1, '1 editor');
			BEGIN { $main::tests += 1; }
		},
	},
	{
		# for now, just check if there are no warnings generated
		delay => 1500,
		code  => sub {
			my $T = Test::Builder->new;
			my $main = $ide->wx->main;
			$T->diag("setup editor for cyrillic_test.pl");
			$main->setup_editors( catfile($home, 'cyrillic_test.pl') );
			my @editors = $main->pages;
			$T->is_num(scalar(@editors), 2, '2 editor');
			BEGIN { $main::tests += 1; }
		},
	},
	{
		delay => 4000,
		code  => sub {
			my $T = Test::Builder->new;
			$T->diag("exiting");
			$ide->wx->ExitMainLoop;
			$ide->wx->main->Destroy;
		},
	},
);

t::lib::Padre::setup_event($frame, \@events, 0);


$ide->wx->MainLoop;

ok(1, 'finished');
BEGIN { $tests += 1; }


sub event {
	my (%args) = @_;
	return bless \%args, 'Wx::Event';
}

package Wx::Event;
sub IsChecked { return $_[0]->{checked}; }

