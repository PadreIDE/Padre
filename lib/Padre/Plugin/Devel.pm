package Padre::Plugin::Devel;

use 5.008;
use strict;
use warnings;
use Padre::Wx      ();
use Padre::Plugin  ();
use Padre::Current ();

our $VERSION = '0.36';
our @ISA     = 'Padre::Plugin';

#####################################################################
# Padre::Plugin Methods

sub padre_interfaces {
	'Padre::Plugin' => 0.26, 'Padre::Wx::Main' => 0.26,;
}

sub plugin_name {
	Wx::gettext('Padre Developer Tools');
}

sub plugin_enable {
	my $self = shift;

	# Load our non-core dependencies=
	require Devel::Dumpvar;

	# Load our configuration
	# (Used for testing purposes)
	$self->{config} = $self->config_read;

	return 1;
}

sub plugin_disable {
	my $self = shift;

	# Save our configuration
	# (Used for testing purposes)
	if ( $self->{config} ) {
		$self->{config}->{foo}++;
		$self->config_write( delete( $self->{config} ) );
	} else {
		$self->config_write( { foo => 1 } );
	}

	return 1;
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		Wx::gettext('Run Document inside Padre') => 'eval_document',
		'---'                                    => undef,
		Wx::gettext('Dump Current Document')     => 'dump_document',
		Wx::gettext('Dump Top IDE Object')       => 'dump_padre',
		Wx::gettext('Dump %INC and @INC')        => 'dump_inc',
		'---'                                    => undef,

		# TODO
		# Should be checkbox but I am too lazy to turn the whole
		# menu_plugins_simple into a menu_plugins
		Wx::gettext('Enable logging')             => sub { set_logging(1); },
		Wx::gettext('Disable logging')            => sub { set_logging(0); },
		Wx::gettext('Enable trace when logging')  => sub { set_trace(1); },
		Wx::gettext('Disable trace')              => sub { set_trace(0); },
		'---'                                     => undef,
		Wx::gettext('Simulate Crash')             => 'simulate_crash',
		Wx::gettext('Simulate Crashing Bg Task')  => 'simulate_task_crash',
		'---'                                     => undef,
		Wx::gettext('wxWidgets 2.8.10 Reference') => sub {
			Padre::Wx::launch_browser('http://docs.wxwidgets.org/2.8.10/');
		},
		Wx::gettext('STC Reference') => sub {
			Padre::Wx::launch_browser('http://www.yellowbrain.com/stc/index.html');
		},
		'---'                => undef,
		Wx::gettext('About') => 'show_about',
	];
}

#####################################################################
# Plugin Methods

sub set_logging {
	my ($on) = @_;

	Padre->ide->wx->config->set( logging => $on );
	Padre::Util::set_logging($on);
	Padre::Util::debug("After setting debugging to '$on'");
	Padre->ide->wx->main->refresh;

	return;
}

sub set_trace {
	my ($on) = @_;

	Padre->ide->wx->config->set( logging_trace => $on );
	Padre::Util::set_trace($on);
	Padre::Util::debug("After setting trace to '$on'");
	Padre->ide->wx->main->refresh;

	return;
}

sub eval_document {
	my $self = shift;
	my $document = Padre::Current->document or return;
	return $self->_dump_eval( $document->text_get );
}

sub dump_document {
	my $self     = shift;
	my $document = Padre::Current->document;
	unless ($document) {
		Padre::Current->main->message( Wx::gettext('No file is open'), 'Info' );
		return;
	}
	return $self->_dump($document);
}

sub dump_padre {
	my $self = shift;
	return $self->_dump( Padre->ide );
}

sub dump_inc {
	my $self = shift;
	return $self->_dump( \%INC, \@INC );
}

sub simulate_crash {
	require POSIX;
	POSIX::_exit();
}

sub simulate_task_crash {
	require Padre::Task::Debug::Crashing;
	Padre::Task::Debug::Crashing->new()->schedule();
}

sub show_about {
	my $self  = shift;
	my $about = Wx::AboutDialogInfo->new;
	$about->SetName('Padre::Plugin::Devel');
	$about->SetDescription( Wx::gettext("A set of unrelated tools used by the Padre developers\n") );
	Wx::AboutBox($about);
	return;
}

# Takes a string, which it evals and then dumps to Output
sub _dump_eval {
	my $self = shift;
	my $code = shift;

	# Evecute the code and handle errors
	my @rv = eval $code;    ## no critic
	if ($@) {
		Padre::Current->main->error( sprintf( Wx::gettext("Error: %s"), $@ ) );
		return;
	}

	return $self->_dump(@rv);
}

sub _dump {
	my $self = shift;
	my $main = Padre::Current->main;

	# Generate the dump string and set into the output window
	$main->output->SetValue(
		Devel::Dumpvar->new(
			to => 'return',
			)->dump(@_)
	);
	$main->output->SetSelection( 0, 0 );
	$main->show_output(1);

	return;
}

1;

=pod

=head1 NAME

Padre::Plugin::Devel - tools used by the Padre developers

=head1 DESCRIPTION

=head2 Run in Padre

Executes and evaluates the contents of the current (saved or unsaved)
document within the current Padre process, and then dumps the result
of the evaluation to Output.

=head2 Show %INC

Dumps the %INC hash to Output

=head2 Info

=head2 About

=head1 AUTHOR

Gabor Szabo

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
