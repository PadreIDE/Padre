package Padre::Wx::Menu::Help;

# Fully encapsulated help menu

use 5.008;
use strict;
use warnings;
use utf8;
use Padre::Config::Constants qw{ $PADRE_CONFIG_DIR };
use Padre::Wx                ();
use Padre::Wx::Menu          ();
use Padre::Wx::DocBrowser    ();

our $VERSION = '0.29';
use base 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);
	$self->{main} = $main;

	# Add the POD-based help launchers
	Wx::Event::EVT_MENU( $main,
		$self->Append( Wx::wxID_HELP, '' ),
		sub {
			$_[0]->menu->help->help($_[0]);
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Context Help\tF1") ),
		sub {
			my $current = Wx::Window::FindFocus();
			if ( (defined $current) and $current->isa('Padre::Wx::ErrorList') ) {
				$_[0]->errorlist->on_menu_help_context_help;
			} else {
				# TODO This feels wrong, the help menu code shouldn't
				# populate the main window hash.
				my $selection = $_[0]->current->text;
				$_[0]->menu->help->help($_[0]);
				if ( $selection ) {
					$_[0]->{help}->help( $selection );
				}
				return;
			}
		},
	);
       Wx::Event::EVT_MENU( $main,
                $self->Append( -1, Wx::gettext('Current Document') ),
                sub {
                        $_[0]->menu->help->help($_[0]);
			my $doc = $_[0]->current->document;
			$_[0]->{help}->help( $doc );
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

	# Add Padre website tools
	$self->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Report a New &Bug") ),
		sub {
			Wx::LaunchDefaultBrowser('http://padre.perlide.org/wiki/Tickets');
		},
	);
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("View All &Open Bugs") ),
		sub {
			Wx::LaunchDefaultBrowser('http://padre.perlide.org/report/1');
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

# TODO - This violates encapsulation, a menu entry shouldn't be
#        spawning windows and storing them in the window hash.
sub help {
	my $self = shift;
	my $main = shift;

	unless ( $main->{help} ) {
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
        my ($self,$event) = @_;
	my $help = Padre->ide->wx->main->{help};

        if ( $event->CanVeto ) {
                $help->Hide;
        }
        else {
                delete Padre->ide->wx->main->{help};
                $help->Destroy;
        }
}

sub about {
	my $self = shift;

	my $about = Wx::AboutDialogInfo->new;
	$about->SetName("Padre");
	$about->SetDescription(
		"Perl Application Development and Refactoring Environment\n\n" .
		"Based on Wx.pm $Wx::VERSION and " . Wx::wxVERSION_STRING . "\n" .
		"Config at $PADRE_CONFIG_DIR\n" .
		"SQLite user_version at " . Padre::DB->pragma('user_version') . "\n"
	);
	$about->SetVersion($Padre::VERSION);
	$about->SetCopyright( Wx::gettext("Copyright 2008-2009 The Padre development team as listed in Padre.pm"));

	# Only Unix/GTK native about box supports websites
	if ( Padre::Util::WXGTK ) {
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
	$about->AddDeveloper("Gábor Szabó - גאבור סבו ");
	$about->AddDeveloper("Heiko Jansen");
	$about->AddDeveloper("Jérôme Quelin");
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
	$about->AddTranslator("Spanish - Paco Alguacil");
	$about->AddTranslator("Spanish - Enrique Nell");	

	Wx::AboutBox( $about );
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
