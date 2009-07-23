package Padre::Wx::Menu::Help;

# Fully encapsulated help menu

use 5.008;
use strict;
use warnings;
use utf8;
use Padre::Constant ();
use Padre::Current '_CURRENT';
use Padre::Locale   ();
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.41';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);
	$self->{main} = $main;

	# Add the POD-based help launchers
	Wx::Event::EVT_MENU(
		$main,
		$self->Append( Wx::wxID_HELP, '' ),
		sub {
			$_[0]->menu->help->help( $_[0] );
		},
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext("Context Help\tF1") ),
		sub {
			my $focus = Wx::Window::FindFocus();
			if ( ( defined $focus ) and $focus->isa('Padre::Wx::ErrorList') ) {
				$_[0]->errorlist->on_menu_help_context_help;
			} else {

				# TODO This feels wrong, the help menu code shouldn't
				# populate the main window hash.
				my $selection = $_[0]->current->text;
				$_[0]->menu->help->help( $_[0] );
				if ($selection) {
					$_[0]->{help}->help($selection);
				}
				return;
			}
		},
	);
	$self->{current} = $self->Append( -1, Wx::gettext('Current Document') );
	Wx::Event::EVT_MENU(
		$main,
		$self->{current},
		sub {
			$_[0]->menu->help->help( $_[0] );
			$_[0]->{help}->help( $_[0]->current->document );
		},
	);

	# Live Support
	$self->AppendSeparator;

	$self->{live} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Live Support"),
		$self->{live}
	);

	Wx::Event::EVT_MENU(
		$main,
		$self->{live}->Append( -1, Wx::gettext('Padre Support (English)') ),
		sub {
			Padre::Wx::launch_irc('padre');
		},
	);

	$self->{live}->AppendSeparator;

	Wx::Event::EVT_MENU(
		$main,
		$self->{live}->Append( -1, Wx::gettext('Perl Help') ),
		sub {
			Padre::Wx::launch_irc('general');
		},
	);

	if (Padre::Util::WIN32) {

		Wx::Event::EVT_MENU(
			$main,
			$self->{live}->Append( -1, Wx::gettext('Win32 Questions (English)') ),
			sub {
				Padre::Wx::launch_irc('win32');
			},
		);
	}

	# Add interesting and helpful websites
	$self->AppendSeparator;

	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext('Visit the PerlMonks') ),
		sub {
			Padre::Wx::launch_browser('http://perlmonks.org/');
		},
	);

	# Add Padre website tools
	$self->AppendSeparator;
	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext("Report a New &Bug") ),
		sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/wiki/Tickets');
		},
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext("View All &Open Bugs") ),
		sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/report/1');
		},
	);

	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext("&Translate Padre...") ),
		sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/wiki/TranslationIntro');
		},
	);

	# Add the About
	$self->AppendSeparator;
	Wx::Event::EVT_MENU(
		$main,
		$self->Append( Wx::wxID_ABOUT, Wx::gettext("&About") ),
		sub {
			$_[0]->menu->help->about;
		},
	);

	return $self;
}

sub refresh {
	my $self    = shift;
	my $current = _CURRENT(@_);
	my $hasdoc  = $current->document ? 1 : 0;

	# Don't show "Current Document" unless there is one
	$self->{current}->Enable($hasdoc);

	return 1;
}

# TODO - This violates encapsulation, a menu entry shouldn't be
#        spawning windows and storing them in the window hash.
sub help {
	my $self = shift;
	my $main = shift;

	unless ( $main->{help} ) {
		require Padre::Wx::DocBrowser;
		$main->{help} = Padre::Wx::DocBrowser->new;
		Wx::Event::EVT_CLOSE(
			$main->{help},
			\&on_help_close,
		);
		$main->{help}->help('Padre');
	}
	$main->{help}->SetFocus;
	$main->{help}->Show(1);
	return;
}

# TODO - this feels utterly backwards to me
sub on_help_close {
	my ( $self, $event ) = @_;
	my $help = Padre->ide->wx->main->{help};

	if ( $event->CanVeto ) {
		$help->Hide;
	} else {
		delete Padre->ide->wx->main->{help};
		$help->Destroy;
	}
}

sub about {
	my $self = shift;

	my $about = Wx::AboutDialogInfo->new;
	$about->SetName("Padre");
	$about->SetDescription( "Perl Application Development and Refactoring Environment\n\n"
			. "Based on Wx.pm $Wx::VERSION and "
			. Wx::wxVERSION_STRING . "\n"
			. "Config at "
			. Padre::Constant::CONFIG_DIR . "\n"
			. "SQLite user_version at "
			. Padre::DB->pragma('user_version')
			. "\n" );
	$about->SetVersion($Padre::VERSION);
	$about->SetCopyright( Wx::gettext("Copyright 2008-2009 The Padre development team as listed in Padre.pm") );

	# Only Unix/GTK native about box supports websites
	if (Padre::Constant::WXGTK) {
		$about->SetWebSite("http://padre.perlide.org/");
	}

	$about->AddDeveloper("Adam Kennedy");
	$about->AddDeveloper("Ahmad Zawawi - أحمد محمد زواوي");
	$about->AddDeveloper("Breno G. de Oliveira");
	$about->AddDeveloper("Brian Cassidy");
	$about->AddDeveloper("Cezary Morga");
	$about->AddDeveloper("Chris Dolan");
	$about->AddDeveloper("Claudio Ramirez");
	$about->AddDeveloper("Fayland Lam");
	$about->AddDeveloper("Gabriel Vieira");
	$about->AddDeveloper("Gábor Szabó - גאבור סבו ");
	$about->AddDeveloper("Heiko Jansen");
	$about->AddDeveloper("Jérôme Quelin");
	$about->AddDeveloper("Kaare Rasmussen");
	$about->AddDeveloper("Keedi Kim - 김도형");
	$about->AddDeveloper("Kenichi Ishigaki - 石垣憲一");
	$about->AddDeveloper("Max Maischein");
	$about->AddDeveloper("Patrick Donelan");
	$about->AddDeveloper("Paweł Murias");
	$about->AddDeveloper("Petar Shangov");
	$about->AddDeveloper("Ryan Niebur");
	$about->AddDeveloper("Steffen Müller");

	$about->AddTranslator("Arabic - Ahmad Zawawi - أحمد محمد زواوي");
	$about->AddTranslator("German - Heiko Jansen");
	$about->AddTranslator("French - Jérôme Quelin");
	$about->AddTranslator("Hebrew - Omer Zak - עומר זק");
	$about->AddTranslator("Hebrew - Shlomi Fish - שלומי פיש");
	$about->AddTranslator("Hebrew - Amir E. Aharoni - אמיר א. אהרוני");
	$about->AddTranslator("Hungarian - György Pásztor");
	$about->AddTranslator("Italian - Simone Blandino");
	$about->AddTranslator("Japanese - Kenichi Ishigaki - 石垣憲一");
	$about->AddTranslator("Korean - Keedi Kim - 김도형");
	$about->AddTranslator("Norwegian - Kjetil Skotheim");
	$about->AddTranslator("Russian - Andrew Shitov");
	$about->AddTranslator("Dutch - Dirk De Nijs");
	$about->AddTranslator("Polish - Cezary Morga");
	$about->AddTranslator("Portuguese (BR) - Breno G. de Oliveira");
	$about->AddTranslator("Spanish - Paco Alguacil");
	$about->AddTranslator("Spanish - Enrique Nell");
	$about->AddTranslator("Czech - Marcela Mašláňová");
	$about->AddTranslator("Chinese (Trad./TW) - BlueT - Matthew Lien - 練喆明");

	Wx::AboutBox($about);
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
