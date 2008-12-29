package Padre::Wx::Menu::Help;

# Second attempt to build an fully encapsulated help menu.
# (As a test bed for doing it for the bigger ones)
# Whoever ripped my last attempt apart and made it a trivial
# container for functions instead of a real menu, please leave
# this one alone for now. :(
# Adam K

use 5.008;
use strict;
use warnings;
use utf8;
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

	# Add the POD-based help launchers
	Wx::Event::EVT_MENU( $main,
		$self->Append( Wx::wxID_HELP, '' ),
		sub {
			$_[0]->menu->help->help($_[0]);
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Context Help\tCtrl-Shift-H") ),
		sub {
			# TODO This feels wrong, the help menu code shouldn't
			# populate the mainwindow hash.
			my $selection = $_[0]->selected_text;
			$_[0]->menu->help->help($_[0]);
			if ( $selection ) {
				$_[0]->{help}->show( $selection );
			}
			return;
		},
	);

	# Add interesting and helpful websites
	$self->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext('Visit the PerlMonks') ),
		sub {
			Wx::LaunchDefaultBrowser('http://perlmonks.org/');
		},
	);

	# Add the About
	$self->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$self->Append( Wx::wxID_ABOUT, Wx::gettext("&About") ),
		sub {
			$_[0]->menu->help->about;
		},
	);

	return $self;
}

# TODO - This violates encapsulation, a menu entry should be
#        spawning windows and storing them in the window hash.
sub help {
	my $self = shift;
	my $main = shift;

	unless ( $main->{help} ) {
		$main->{help} = Padre::Pod::Frame->new;
		my $module = Padre::DB->get_last_pod || 'Padre';
		if ( $module ) {
			$main->{help}->{html}->display($module);
		}
	}
	$main->{help}->SetFocus;
	$main->{help}->Show(1);
	return;
}

sub about {
	my $self = shift;

	my $about = Wx::AboutDialogInfo->new;
	$about->SetName("Padre");
	$about->SetDescription(
		"Perl Application Development and Refactoring Environment\n\n" .
		"Based on Wx.pm $Wx::VERSION and " . Wx::wxVERSION_STRING . "\n" .
		"Config at " . Padre->ide->config_dir . "\n"
	);
	$about->SetVersion($Padre::VERSION);
	$about->SetCopyright( Wx::gettext("Copyright 2008 Gabor Szabo"));
	# Only Unix/GTK native about box supports websites
	if ( Padre::Util::UNIX ) {
		$about->SetWebSite("http://padre.perlide.org/");
	}
	$about->AddDeveloper("Adam Kennedy");
	$about->AddDeveloper("Ahmad Zawawi - أحمد محمد زواوي");
	$about->AddDeveloper("Brian Cassidy");
	$about->AddDeveloper("Chris Dolan");
	$about->AddDeveloper("Fayland Lam");
	$about->AddDeveloper("Gábor Szabó - גאבור סבו ");
	$about->AddDeveloper("Heiko Jansen");
	$about->AddDeveloper("Jerome Quelin");
	$about->AddDeveloper("Kaare Rasmussen");
	$about->AddDeveloper("Keedi Kim - 김도형");
	$about->AddDeveloper("Max Maischein");
	$about->AddDeveloper("Patrick Donelan");
	$about->AddDeveloper("Paweł Murias");
	$about->AddDeveloper("Petar Shangov");
	$about->AddDeveloper("Steffen Müller");

 	$about->AddTranslator("Arabic - Ahmad Zawawi - أحمد محمد زواوي");
	$about->AddTranslator("German - Heiko Jansen");
	$about->AddTranslator("French - Jérôme Quelin");
	$about->AddTranslator("Hebrew - Omer Zak - עומר זק");
	$about->AddTranslator("Hebrew - Shlomi Fish - שלומי פיש");
	$about->AddTranslator("Hungarian - György Pásztor");
	$about->AddTranslator("Italian - Simone Blandino");
	$about->AddTranslator("Korean - Keedi Kim - 김도형");
	$about->AddTranslator("Russian - Andrew Shitov");
	$about->AddTranslator("Dutch - Dirk De Nijs");
	$about->AddTranslator("Portuguese (BR) - Breno G. de Oliveira");

	Wx::AboutBox( $about );
	return;
}

1;
