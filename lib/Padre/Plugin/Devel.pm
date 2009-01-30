package Padre::Plugin::Devel;

use 5.008;
use strict;
use warnings;
use Padre::Wx      ();
use Padre::Plugin  ();
use Padre::Current ();

our $VERSION = '0.26';
our @ISA     = 'Padre::Plugin';





#####################################################################
# Padre::Plugin Methods

sub padre_interfaces {
	'Padre::Plugin'   => 0.26,
	'Padre::Wx::Main' => 0.26,
}

sub plugin_name {
	'Padre Developer Tools';
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
	my $self   = shift;

	# Save our configuration
	# (Used for testing purposes)
	if ( $self->{config} ) {
		$self->{config}->{foo}++;
		$self->config_write( delete($self->{config}) );
	} else {
		$self->config_write( { foo => 1 } );
	}

	return 1;
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		'Run Document inside Padre' => 'eval_document',
		'---'                       => undef,
		'Dump Current Document'     => 'dump_document',
		'Dump Top IDE Object'       => 'dump_padre',
		'Dump %INC HASH'            => 'dump_inc',
		'---'                       => undef,
		'Simulate Crash'            => 'simulate_crash',
		'---'                       => undef,
		'wxWidgets 2.8.8 Reference' => sub {
			Wx::LaunchDefaultBrowser('http://docs.wxwidgets.org/2.8.8/');
		},
		'---'                       => undef,
		'About'                     => 'show_about',
	];
}





#####################################################################
# Plugin Methods

sub eval_document {
	my $self     = shift;
	my $document = $self->current->document or return;
	return $self->_dump_eval( $document->text_get );
}

sub dump_document {
	my $self     = shift;
	my $document = Padre::Current->document;
	unless ( $document ) {
		Padre::Current->main->message( 'No file is open', 'Info' );
		return;
	}
	return $self->_dump( $document );
}

sub dump_padre {
	my $self = shift;
	return $self->_dump( Padre->ide );
}

sub dump_inc {
	my $self = shift;
	return $self->_dump( \%INC );
}

sub simulate_crash {
	require POSIX;
	POSIX::_exit();
}

sub show_about {
	my $self  = shift;
	my $about = Wx::AboutDialogInfo->new;
	$about->SetName('Padre::Plugin::Devel');
	$about->SetDescription(
		"A set of unrelated tools used by the Padre developers\n"
	);
	Wx::AboutBox( $about );
	return;
}

# Takes a string, which it evals and then dumps to Output
sub _dump_eval {
	my $self = shift;
	my $code = shift;

	# Evecute the code and handle errors
	my @rv = eval $code; ## no critic
	if ( $@ ) {
		Padre::Current->main->error(
			sprintf(Wx::gettext("Error: %s"), $@)
		);
		return;
	}

	return $self->_dump( @rv );
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
	$main->output->SetSelection(0, 0);
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

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
