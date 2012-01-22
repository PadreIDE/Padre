package Padre::Plugin::Devel;

use 5.008;
use strict;
use warnings;
use Padre::Wx     ();
use Padre::Util   ();
use Padre::Plugin ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Plugin';





#####################################################################
# Padre::Plugin Methods

sub padre_interfaces {
	return (
		'Padre::Plugin'                       => 0.91,
		'Padre::Wx'                           => 0.91,
		'Padre::Wx::Main'                     => 0.91,
		'Padre::Wx::TextEntryDialog::History' => 0.85,
	);
}

sub plugin_name {
	Wx::gettext('Padre Developer Tools');
}

# Core plugins may reuse the page icon
sub plugin_icon {
	require Padre::Wx::Icon;
	Padre::Wx::Icon::find('logo');
}

sub plugin_enable {
	my $self = shift;

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

	# Close the introspection tool
	if ( $self->{expression} ) {
		delete( $self->{expression} )->Destroy;
	}

	# Unload our dialog classes
	$self->unload(
		qw{
			Padre::Wx::Dialog::Expression
			Padre::Wx::FBP::Expression
			}
	);

	return 1;
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		Wx::gettext('Evaluate &Expression') . '...' => 'expression',

		'---' => undef,

		Wx::gettext('Run &Document inside Padre')  => 'eval_document',
		Wx::gettext('Run &Selection inside Padre') => 'eval_selection',

		'---' => undef,

		Wx::gettext('&Load All Padre Modules')        => 'load_everything',
		Wx::gettext('Simulate &Crash')                => 'simulate_crash',
		Wx::gettext('Simulate Background &Exception') => 'simulate_task_exception',
		Wx::gettext('Simulate &Background Crash')     => 'simulate_task_crash',
		Wx::gettext('&Start/Stop sub trace')          => 'trace_sub_startstop',

		'---' => undef,

		sprintf( Wx::gettext('&wxWidgets %s Reference'), '2.8.12' ) => sub {
			Padre::Wx::launch_browser('http://docs.wxwidgets.org/2.8.12/');
		},
		Wx::gettext('&Scintilla Reference') => sub {
			Padre::Wx::launch_browser('http://www.scintilla.org/ScintillaDoc.html');
		},
		Wx::gettext('wxPerl &Live Support') => sub {
			Padre::Wx::launch_irc('wxperl');
		},

		'---' => undef,

		Wx::gettext('&About') => 'show_about',
	];
}





#####################################################################
# Plugin Methods

sub expression {
	my $self = shift;
	my $main = $self->main;

	unless ( $self->{expression} ) {

		# Load and show the expression dialog
		require Padre::Wx::Dialog::Expression;
		$self->{expression} = Padre::Wx::Dialog::Expression->new($main);
	}
	$self->{expression}->Show;
	$self->{expression}->SetFocus;

	return;
}

sub eval_document {
	my $self = shift;
	my $document = $self->current->document or return;
	return $self->_dump_eval( $document->text_get );
}

sub eval_selection {
	my $self = shift;
	my $document = $self->current->document or return;
	return $self->_dump_eval( $self->current->text );
}

sub trace_sub_startstop {
	my $self = shift;
	my $main = $self->current->main;

	if ( defined( $self->{trace_sub_before} ) ) {
		delete $self->{trace_sub_before};
		delete $self->{trace_sub_after};
		$main->info( Wx::gettext('Sub-tracing stopped') );
		return;
	}

	eval 'use Aspect;';
	if ($@) {
		$main->error( Wx::gettext('Error while loading Aspect, is it installed?') . "\n$@" );
		return;
	}

	eval '
	$self->{trace_sub_before} = before {
			print STDERR "enter ".shift->{sub_name}."\n";
		} call qr/^Padre::/;
	$self->{trace_sub_after} = after {
			print STDERR "leave ".shift->{sub_name}."\n";
		} call qr/^Padre::/;
';
	$main->info( Wx::gettext('Sub-tracing started') );

}

sub simulate_crash {
	require POSIX;
	POSIX::_exit();
}

# Simulate a background thread that does an uncaught exception/die
sub simulate_task_exception {
	require Padre::Task::Eval;
	Padre::Task::Eval->new(
		run    => 'sleep 5; die "This is a debugging task that simply crashes after running for 5 seconds!";',
		finish => 'warn "This should never be reached";',
	)->schedule;
}

# Simulate a background thread that does a hard exit/segfault
sub simulate_task_crash {
	require Padre::Task::Eval;
	Padre::Task::Eval->new(
		run    => 'sleep 5; exit(1);',
		finish => 'warn "This should never be reached";',
	)->schedule;
}

sub show_about {
	my $self  = shift;
	my $about = Wx::AboutDialogInfo->new;
	$about->SetName('Padre::Plugin::Devel');
	$about->SetDescription( Wx::gettext("A set of unrelated tools used by the Padre developers\n") );
	Wx::AboutBox($about);
	return;
}

sub load_everything {
	my $self = shift;
	my $main = $self->current->main;

	# Find the location of Padre.pm
	my $padre = $INC{'Padre.pm'};
	my $parent = substr( $padre, 0, -3 );

	# Find everything under Padre:: with a matching version
	require File::Find::Rule;
	my @children = grep { not $INC{$_} }
		map {"Padre/$_->[0]"}
		grep { defined( $_->[1] ) and $_->[1] eq $VERSION }
		map { [ $_, Padre::Util::parse_variable( File::Spec->catfile( $parent, $_ ) ) ] }
		File::Find::Rule->name('*.pm')->file->relative->in($parent);
	$main->message( sprintf( Wx::gettext('Found %s unloaded modules'), scalar @children ) );
	return unless @children;

	# Load all of them (ignoring errors)
	my $loaded = 0;
	foreach my $child (@children) {
		eval { require $child; };
		next if $@;
		$loaded++;
	}

	# Say how many classes we loaded
	$main->message( sprintf( Wx::gettext('Loaded %s modules'), $loaded ) );
}

# Takes a string, which it evals and then dumps to Output
sub _dump_eval {
	my $self = shift;
	my $code = shift;

	# Evecute the code and handle errors
	my @rv = eval $code;
	if ($@) {
		$self->current->main->error( sprintf( Wx::gettext("Error: %s"), $@ ) );
		return;
	}

	return $self->_dump(@rv);
}

sub _dump {
	my $self = shift;
	my $main = $self->current->main;

	# Generate the dump string and set into the output window
	require Devel::Dumpvar;
	$main->output->SetValue( Devel::Dumpvar->new( to => 'return' )->dump(@_) );
	$main->output->SetSelection( 0, 0 );
	$main->show_output(1);

	return;
}

1;

=pod

=head1 NAME

Padre::Plugin::Devel - tools used by the Padre developers

=head1 DESCRIPTION

=head2 Run Document inside Padre

Executes and evaluates the contents of the current (saved or unsaved)
document within the current Padre process, and then dumps the result
of the evaluation to Output.

=head2 Dump Current Document

=head2 Dump Top IDE Object

=head2 Dump %INC and @INC

Dumps the %INC hash to Output

=head2 Enable/Disable logging

=head2 Enable/Disable trace when logging

=head2 Simulate crash

=head2 wxWidgets 2.8.12 Reference

=head2 C<Scintilla> reference

Documentation for C<Wx::Scintilla>, a Scintilla source code editing component for wxWidgets

=head2 C<wxPerl> Live Support

Connects to C<#wxperl> on C<irc.perl.org>, where people can answer queries on wxPerl problems/usage.

=head2 About

=head1 AUTHOR

Gábor Szabó

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
