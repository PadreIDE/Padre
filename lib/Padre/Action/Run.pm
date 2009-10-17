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
use Padre::Action ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.48';

#####################################################################

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Script Execution
	Padre::Action->new(
		name         => 'run.run_document',
		need_editor  => 1,
		need_runable => 1,
		label        => Wx::gettext('Run Script'),
		comment      => Wx::gettext('Runs the current document and shows its output in the output panel.'),
		shortcut     => 'F5',
		need_editor  => 1,
		need_file    => 1,
		need_runable => 1,
		menu_event   => sub {
			$_[0]->run_document;
			$_[0]->refresh_toolbar( $_[0]->current );
		},
	);

	Padre::Action->new(
		name         => 'run.run_document_debug',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('Run Script (debug info)'),
		comment      => Wx::gettext( 'Run the current document but include ' . 'debug info in the output.' ),
		shortcut     => 'Shift-F5',
		need_editor  => 1,
		menu_event   => sub {
			$_[0]->run_document(1); # Enable debug info
		},
	);

	Padre::Action->new(
		name       => 'run.run_command',
		label      => Wx::gettext('Run Command'),
		comment    => Wx::gettext('Runs a shell command and shows the output.'),
		shortcut   => 'Ctrl-F5',
		menu_event => sub {
			$_[0]->on_run_command;
		},
	);

	Padre::Action->new(
		name        => 'run.run_tests',
		need_editor => 1,
		need_file   => 1,
		label       => Wx::gettext('Run Tests'),
		comment     => Wx::gettext(
			'Run all tests for the current project or document and show the results in ' . 'the output panel.'
		),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->on_run_tests;
		},
	);

	Padre::Action->new(
		name         => 'run.run_this_test',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		need         => sub {
			my %objects = @_;
			return 0 if !defined( $objects{document} );
			return 0 if !defined( $objects{document}->{file} );
			return $objects{document}->{file}->{filename} =~ /\.t$/;
		},
		label       => Wx::gettext('Run This Test'),
		comment     => Wx::gettext('Run the current test if the current document is a test.'),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->on_run_this_test;
		},
	);

	Padre::Action->new(
		name => 'run.stop',
		need => sub {
			my %objects = @_;
			return $main->{command} ? 1 : 0;
		},
		label      => Wx::gettext('Stop execution'),
		comment    => Wx::gettext('Stop a running task.'),
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
