package Padre::Wx::Debugger;

=pod

=head1 NAME

Padre::Wx::Debugger - Interface to the Perl debugger.

=head1 DESCRIPTION

Padre::Wx::Debugger provides a wrapper for the generalised L<Debug::Client>.

It should really live at Padre::Debugger, but does not currently have
sufficient abstraction from L<Wx>.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Current ();
use Padre::Wx      ();
use Padre::Logger;

our $VERSION = '0.90';

=pod

=head2 new

Simple constructor.

=cut

sub new {
	my $class = shift;
	my $self  = bless {
		client => undef,
		file   => undef,
		save   => {},
	}, $class;
	return $self;
}

sub message {
	Padre::Current->main->message( $_[1] );
}

sub error {
	Padre::Current->main->error( $_[1] );
}

=pod

=head2 debug_perl

  $main->debug_perl;

Run current document under Perl debugger. An error is reported if
current is not a Perl document.

Returns true if debugger successfully started.

=cut

sub debug_perl {
	my $self     = shift;
	my $current  = Padre::Current->new;
	my $main     = $current->main;
	my $document = $current->document;
	my $editor   = $current->editor;

	$main->show_debug(1);

	if ( $self->{client} ) {
		$main->error( Wx::gettext('Debugger is already running') );
		return;
	}
	unless ( $document->isa('Padre::Document::Perl') ) {
		$main->error( Wx::gettext('Not a Perl document') );
		return;
	}

	# Apply the user's save-on-run policy
	# TO DO: Make this code suck less
	my $config = $main->config;
	if ( $config->run_save eq 'same' ) {
		$main->on_save;
	} elsif ( $config->run_save eq 'all_files' ) {
		$main->on_save_all;
	} elsif ( $config->run_save eq 'all_buffer' ) {
		$main->on_save_all;
	}

	# Get the filename
	my $filename = defined( $document->{file} ) ? $document->{file}->filename : undef;

	# TODO: improve the message displayed to the user
	# If the document is not saved, simply return for now
	return unless $filename;

	# Set up the debugger
	my $host = 'localhost';
	my $port = 12345 + int rand(1000); # TODO make this configurable?
	SCOPE: {
		local $ENV{PERLDB_OPTS} = "RemotePort=$host:$port";
		$main->run_command( $document->get_command( { debug => 1 } ) );
	}

	# Bootstrap the debugger
	require Debug::Client;
	$self->{client} = Debug::Client->new(
		host => $host,
		port => $port,
	);
	$self->{client}->listen;

	$self->{file} = $filename;

	my ( $module, $file, $row, $content ) = $self->{client}->get;

	my $save = ( $self->{save}->{$filename} ||= {} );
	if ( $save->{breakpoints} ) {
		foreach my $file ( keys %{ $save->{breakpoints} } ) {
			foreach my $row ( keys %{ $save->{breakpoints}->{$file} } ) {

				# TODO what if this fails?
				# TODO find the editor of that $file first!
				$self->{client}->set_breakpoint( $file, $row );
			}
		}
	}

	unless ( $self->_set_debugger ) {
		$main->error( Wx::gettext('Debugging failed. Did you check your program for syntax errors?') );
		$self->debug_perl_quit;
		return;
	}

	return 1;
}

sub _set_debugger {
	my $self    = shift;
	my $current = Padre::Current->new;
	my $main    = $current->main;
	my $editor  = $current->editor or return;
	my $file    = $self->{client}->{filename} or return;
	my $row     = $self->{client}->{row} or return;

	# Open the file if needed
	if ( $editor->{Document}->filename ne $file ) {
		$main->setup_editor($file);
		$editor = $main->current->editor;
	}

	$editor->goto_line_centerize( $row - 1 );

	#### TODO this was taken from the Padre::Wx::Syntax::start() and  changed a bit.
	# They should be reunited soon !!!! (or not)
	$editor->SetMarginType( 1, Wx::wxSTC_MARGIN_SYMBOL );
	$editor->SetMarginWidth( 1, 16 );
	$editor->MarkerDeleteAll(Padre::Wx::MarkLocation);
	$editor->MarkerAdd( $row - 1, Padre::Wx::MarkLocation );

	my $debugger = $main->debugger;
	my $count    = $debugger->GetItemCount;
	foreach my $c ( 0 .. $count - 1 ) {
		my $variable = $debugger->GetItemText($c);
		my $value = eval { $self->{client}->get_value($variable); };
		if ($@) {

			#$main->error(sprintf(Wx::gettext("Could not evaluate '%s'"), $text));
			#return;
		} else {
			$debugger->SetItem( $c, 1, $value );
		}
	}

	return 1;
}

sub running {
	my $self = shift;

	unless ( $self->{client} ) {
		Padre::Current->main->message(
			Wx::gettext(
				"The debugger is not running.\nYou can start the debugger using one of the commands 'Step In', 'Step Over', or 'Run till Breakpoint' in the Debug menu."
			),
			Wx::gettext('Debugger not running')
		);
		return;
	}

	return !!Padre::Current->editor;
}

sub debug_perl_remove_breakpoint {
	my $self = shift;
	$self->running or return;

	my $editor = Padre::Current->editor;
	my $file   = $editor->{Document}->filename;
	my $row    = $editor->GetCurrentLine + 1;
	$self->{client}->remove_breakpoint( $file, $row );
	delete $self->{save}->{ $self->{file} }->{breakpoints}->{$file}->{$row};

	return;
}

sub debug_perl_set_breakpoint {
	my $self = shift;
	$self->running or return;

	my $editor = Padre::Current->editor;
	my $file   = $editor->{Document}->filename;
	my $row    = $editor->GetCurrentLine + 1;

	# TODO ask for a condition
	# TODO allow setting breakpoints even before the script and the debugger runs
	# (by saving it in the debugger configuration file?)
	if ( not $self->{client}->set_breakpoint( $file, $row ) ) {
		$self->error( sprintf( Wx::gettext("Could not set breakpoint on file '%s' row '%s'"), $file, $row ) );
		return;
	}
	$editor->MarkerAdd( $row - 1, Padre::Wx::MarkBreakpoint() );

	# TODO: This should be the condition I guess
	$self->{save}->{ $self->{file} }->{breakpoints}->{$file}->{$row} = 1;

	return;
}

sub debug_perl_list_breakpoints {
	my $self = shift;
	$self->running or return;

	# LIST context crashes in Debug::Client 0.10
	$self->message( scalar $self->{client}->list_break_watch_action );

	return;
}

sub debug_perl_jumpt_to {
	my $self = shift;
	$self->running or return;
	$self->_set_debugger;
	return;
}

sub debug_perl_quit {
	my $self = shift;
	$self->running or return;

	# Clean up the GUI artifacts
	my $current = Padre::Current->new;
	$current->main->show_debug(0);
	$current->editor->MarkerDeleteAll(Padre::Wx::MarkLocation);

	# Detach the debugger
	$self->{client}->quit;
	delete $self->{client};

	return;
}

sub debug_perl_step_in {
	my $self = shift;

	unless ( $self->{client} ) {
		unless ( $self->debug_perl ) {
			Padre::Current->main->error( Wx::gettext('Debugger not running') );
			return;
		}

		# No need to make first step
		return;
	}

	my ( $module, $file, $row, $content ) = $self->{client}->step_in;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->debug_perl_quit;
		return;
	}
	$self->_set_debugger;

	return;
}

sub debug_perl_step_over {
	my $self = shift;

	unless ( $self->{client} ) {
		unless ( $self->debug_perl ) {
			Padre::Current->main->error( Wx::gettext('Debugger not running') );
			return;
		}
	}

	my ( $module, $file, $row, $content ) = $self->{client}->step_over;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->debug_perl_quit;
		return;
	}
	$self->_set_debugger;

	return;
}

sub debug_perl_run_to_cursor {
	my $self = shift;
	Padre::Current->main->error("Not implemented");

	# Commented our for critic:
	#	my $file = $current->filename;
	#	my $row  = '';
	#
	#	# put a breakpoint to the cursor and then run till there
	#	$self->debug_perl_run;
}

sub debug_perl_run {
	my $self  = shift;
	my $param = shift;

	unless ( $self->{client} ) {
		unless ( $self->debug_perl ) {
			Padre::Current->main->error( Wx::gettext('Debugger not running') );
			return;
		}
	}

	my ( $module, $file, $row, $content ) = $self->{client}->run($param);
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->debug_perl_quit;
		return;
	}
	$self->_set_debugger;

	return;
}

sub debug_perl_step_out {
	my $self = shift;

	unless ( $self->{client} ) {
		Padre::Current->main->error( Wx::gettext('Debugger not running') );
		return;
	}

	my ( $module, $file, $row, $content ) = $self->{client}->step_out;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->debug_perl_quit;
		return;
	}
	$self->_set_debugger;

	return;
}

sub debug_perl_show_stack_trace {
	my $self = shift;
	$self->running or return;

	my $trace = $self->{client}->get_stack_trace;
	my $str   = $trace;
	if ( ref($trace) and ref($trace) eq 'ARRAY' ) {
		$str = join "\n", @$trace;
	}
	$self->message($str);

	return;
}

sub debug_perl_show_value {
	my $self = shift;
	$self->running or return;

	my $text = $self->_debug_get_variable or return;
	my $value = eval { $self->{client}->get_value($text) };
	if ($@) {
		$self->error( sprintf( Wx::gettext("Could not evaluate '%s'"), $text ) );
		return;
	}
	$self->message("$text = $value");

	return;
}

sub _debug_get_variable {
	my $self = shift;
	my $document = Padre::Current->document or return;

	#my $text = $current->text;
	my ( $location, $text ) = $document->get_current_symbol;
	if ( not $text or $text !~ /^[\$@%\\]/ ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext(
					"'%s' does not look like a variable. First select a variable in the code and then try again."),
				$text
			)
		);
		return;
	}
	return $text;
}

sub debug_perl_display_value {
	my $self = shift;
	$self->running or return;

	my $text     = $self->_debug_get_variable or return;
	my $debugger = Padre::Current->main->debugger;
	my $count    = $debugger->GetItemCount;
	my $idx      = $debugger->InsertStringItem( $count + 1, $text );

	#	my $value = eval { $self->{client}->get_value($text) };
	#	if ($@) {
	#		$main->error(sprintf(Wx::gettext("Could not evaluate '%s'"), $text));
	#		return;
	#	} else {
	#		$debugger->SetItem( $idx, 1, $value );
	#	}
}

sub debug_perl_evaluate_expression {
	my $self = shift;
	$self->running or return;

	my $expression = Padre::Current->main->prompt(
		Wx::gettext("Expression:"),
		Wx::gettext("Expr"),
		"EVAL_EXPRESSION"
	);
	$self->{client}->execute_code($expression);

	return;
}

sub quit {
	my $self = shift;
	if ( $self->{client} ) {
		$self->debug_perl_quit;
	}
	return;
}

1;

# TODO:
# Keep the debugger window open even after ending the script

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
