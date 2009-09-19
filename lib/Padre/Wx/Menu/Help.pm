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

our $VERSION = '0.46';
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
	$self->add_menu_item(
		$self,
		name       => 'help.help',
		id         => Wx::wxID_HELP,
		label      => Wx::gettext('Help'),
		menu_event => sub {
			$_[0]->help();
		},
	);
	$self->add_menu_item(
		$self,
		name       => 'help.context_help',
		label      => Wx::gettext('Context Help'),
# TODO: The F1 shortcut is added a second time somewhere else resulting
#       on no shortcut on Linux and a "F1F1" shortcut on Windows.
#       The TODO is: Find the other place where F1 is defined and remove
#       it there. All key bindings should be defind in menus/actions.
#		shortcut   => 'F1',
		menu_event => sub {
			my $focus = Wx::Window::FindFocus();
			if ( ( defined $focus ) and $focus->isa('Padre::Wx::ErrorList') ) {
				$_[0]->errorlist->on_menu_help_context_help;
			} else {

				# TODO This feels wrong, the help menu code shouldn't
				# populate the main window hash.
				$_[0]->help( $_[0]->current->text );
				return;
			}
		},
	);

	$self->add_menu_item(
		$self,
		name       => 'help.search',
		label      => Wx::gettext('Help Search'),
		shortcut   => 'F2',
		menu_event => sub {

			#Show Help Search with no topic...
			$_[0]->help_search;
		},
	);

	$self->{current} = $self->add_menu_item(
		$self,
		name       => 'help.current',
		label      => Wx::gettext('Current Document'),
		menu_event => sub {
			$_[0]->help( $_[0]->current->document );
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

	$self->add_menu_item(
		$self->{live},
		name       => 'help.live_support',
		label      => Wx::gettext('Padre Support (English)'),
		menu_event => sub {
			Padre::Wx::launch_irc('padre');
		},
	);

	$self->{live}->AppendSeparator;

	$self->add_menu_item(
		$self->{live},
		name       => 'help.perl_help',
		label      => Wx::gettext('Perl Help'),
		menu_event => sub {
			Padre::Wx::launch_irc('general');
		},
	);

	if (Padre::Util::WIN32) {
		$self->add_menu_item(
			$self->{live},
			name       => 'help.win32_questions',
			label      => Wx::gettext('Win32 Questions (English)'),
			menu_event => sub {
				Padre::Wx::launch_irc('win32');
			},
		);
	}

	$self->AppendSeparator;

	# Add interesting and helpful websites
	$self->add_menu_item(
		$self,
		name       => 'help.visit_perlmonks',
		label      => Wx::gettext('Visit the PerlMonks'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://perlmonks.org/');
		},
	);

	$self->AppendSeparator;

	# Add Padre website tools
	$self->add_menu_item(
		$self,
		name       => 'help.report_a_bug',
		label      => Wx::gettext('Report a New &Bug'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/wiki/Tickets');
		},
	);
	$self->add_menu_item(
		$self,
		name       => 'help.view_all_open_bugs',
		label      => Wx::gettext('View All &Open Bugs'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/report/1');
		},
	);

	$self->add_menu_item(
		$self,
		name       => 'help.translate_padre',
		label      => Wx::gettext('&Translate Padre...'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/wiki/TranslationIntro');
		},
	);

	$self->AppendSeparator;

	# Add the About
	$self->add_menu_item(
		$self,
		name       => 'help.about',
		id         => Wx::wxID_ABOUT,
		label      => Wx::gettext('&About'),
		menu_event => sub {
			$_[0]->about->ShowModal;
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


1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
