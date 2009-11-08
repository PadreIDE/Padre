package Padre::Action::Help;

# Fully encapsulated help menu

use 5.008;
use strict;
use warnings;
use utf8;
use Padre::Action   ();
use Padre::Constant ();
use Padre::Current '_CURRENT';
use Padre::Locale ();

our $VERSION = '0.50';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Add the POD-based help launchers
	Padre::Action->new(
		name       => 'help.help',
		id         => Wx::wxID_HELP,
		label      => Wx::gettext('Help'),
		comment    => Wx::gettext('Show the Padre help'),
		menu_event => sub {
			$_[0]->help('Padre');
		},
	);
	Padre::Action->new(
		name       => 'help.context_help',
		label      => Wx::gettext('Context Help'),
		comment    => Wx::gettext('Show the help article for the current context'),
		shortcut   => 'F1',
		menu_event => sub {
			my $focus = Wx::Window::FindFocus();
			if ( ( defined $focus ) and $focus->isa('Padre::Wx::ErrorList') ) {
				$_[0]->errorlist->on_menu_help_context_help;
			} else {

				#Show help for selected text
				$_[0]->help( $_[0]->current->text );
				return;
			}
		},
	);

	Padre::Action->new(
		name       => 'help.search',
		label      => Wx::gettext('Help Search'),
		comment    => 'Search the Perl help pages (perldoc)',
		shortcut   => 'F2',
		menu_event => sub {

			#Show Help Search with no topic...
			$_[0]->help_search;
		},
	);

	$self->{current} = Padre::Action->new(
		name        => 'help.current',
		need_editor => 1,
		label       => Wx::gettext('Current Document'),
		comment     => Wx::gettext('Show the POD (Perldoc) version of the current document'),
		menu_event  => sub {
			$_[0]->help( $_[0]->current->document );
		},
	);

	# Live Support

	Padre::Action->new(
		name    => 'help.live_support',
		label   => Wx::gettext('Padre Support (English)'),
		comment => Wx::gettext(
			      'Open the Padre live support in your default web browser '
				. 'and chat to others who may help you with your problem'
		),
		menu_event => sub {
			Padre::Wx::launch_irc('padre');
		},
	);

	Padre::Action->new(
		name    => 'help.perl_help',
		label   => Wx::gettext('Perl Help'),
		comment => Wx::gettext(
			      'Open the Perl live support in your default web browser '
				. 'and chat to others who may help you with your problem'
		),
		menu_event => sub {
			Padre::Wx::launch_irc('general');
		},
	);

	Padre::Action->new(
		name    => 'help.win32_questions',
		label   => Wx::gettext('Win32 Questions (English)'),
		comment => Wx::gettext(
			      'Open the Perl/Win32 live support in your default web browser '
				. 'and chat to others who may help you with your problem'
		),
		menu_event => sub {
			Padre::Wx::launch_irc('win32');
		},
	);

	# Add interesting and helpful websites
	Padre::Action->new(
		name    => 'help.visit_perlmonks',
		label   => Wx::gettext('Visit the PerlMonks'),
		comment => Wx::gettext(
			'Open perlmonks.org, one of the biggest Perl community sites ' . 'in your default webbrowser'
		),
		menu_event => sub {
			Padre::Wx::launch_browser('http://perlmonks.org/');
		},
	);

	# Add Padre website tools
	Padre::Action->new(
		name       => 'help.report_a_bug',
		label      => Wx::gettext('Report a New &Bug'),
		comment    => Wx::gettext('Send a bug report to the Padre developer team'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/wiki/Tickets');
		},
	);
	Padre::Action->new(
		name       => 'help.view_all_open_bugs',
		label      => Wx::gettext('View All &Open Bugs'),
		comment    => Wx::gettext('View all known and currently unsolved bugs in Padre'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/report/1');
		},
	);

	Padre::Action->new(
		name       => 'help.translate_padre',
		label      => Wx::gettext('&Translate Padre...'),
		comment    => Wx::gettext('Help by translating Padre to your local language'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/wiki/TranslationIntro');
		},
	);

	# Add the About
	Padre::Action->new(
		name       => 'help.about',
		id         => Wx::wxID_ABOUT,
		label      => Wx::gettext('&About'),
		comment    => Wx::gettext('Show the about-Padre information'),
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
