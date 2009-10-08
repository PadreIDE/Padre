package Padre::Action::Run;

# Actions for running the current document

=pod

=head1 NAME

Padre::Action::Run is a outsourced module. It creates Actions for
various options to run the current file.

=cut

use 5.008;
use strict;
use warnings;
use Padre::Action       ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.47';

#####################################################################

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Script Execution
	Padre::Action->new(
		name       => 'run.run_document',
		label      => Wx::gettext('Run Script'),
		shortcut   => 'F5',
		menu_event => sub {
			$_[0]->run_document;
			$_[0]->refresh_toolbar( $_[0]->current );
		},
	);

	Padre::Action->new(
		name       => 'run.run_document_debug',
		label      => Wx::gettext('Run Script (debug info)'),
		shortcut   => 'Shift-F5',
		menu_event => sub {
			$_[0]->run_document(1); # Enable debug info
		},
	);

	Padre::Action->new(
		name       => 'run.run_command',
		label      => Wx::gettext('Run Command'),
		shortcut   => 'Ctrl-F5',
		menu_event => sub {
			$_[0]->on_run_command;
		},
	);

	Padre::Action->new(
		name       => 'run.run_tests',
		label      => Wx::gettext('Run Tests'),
		menu_event => sub {
			$_[0]->on_run_tests;
		},
	);

	Padre::Action->new(
		name       => 'run.run_this_test',
		label      => Wx::gettext('Run This Test'),
		menu_event => sub {
			$_[0]->on_run_this_test;
		},
	);

	Padre::Action->new(
		name       => 'run.stop',
		label      => Wx::gettext('Stop execution'),
		shortcut   => 'F6',
		menu_event => sub {
			if ( $_[0]->{command} ) {
				if (Padre::Constant::WIN32) {
					$_[0]->{command}->KillProcess;
				} else {
					$_[0]->{command}->TerminateProcess;
				}
			}
			delete $_[0]->{command};
			$_[0]->refresh_toolbar( $_[0]->current );
			return;
		},
	);

	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
