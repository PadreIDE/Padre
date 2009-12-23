package Padre::Wx::Debugger;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.53';

use Padre::Wx ();
use Padre::Logger;
use Padre::Util ('_T');

=head1 NAME

Padre::Wx::Debugger - interface to L<Debug::Client>

=head1 DESCRIPTION

=cut

=head3 C<new>

Simple constructor.

=cut

sub new {
	my $class = shift;
	my $self = bless {}, $class;
	return $self;
}

=pod

=head3 C<debug_perl>

    $main->debug_perl;

Run current document under Perl debugger. An error is reported if
current is not a Perl document.

Returns true if debugger successfully started.

=cut

sub debug_perl {
	my $self = shift;

	my $main     = Padre->ide->wx->main;
	my $document = $main->current->document;

	my $editor = $main->current->editor;
	$main->show_debugger(1);

	if ( $self->{_debugger_} ) {
		$main->error( _T('Debugger is already running') );
		return;
	}

	unless ( $document->isa('Padre::Document::Perl') ) {
		$main->error( Wx::gettext("Not a Perl document") );
		return;
	}

	# Check the file name
	my $filename = defined( $document->{file} ) ? $document->{file}->filename : undef;

	#	unless ( $filename =~ /\.pl$/i ) {
	#		return $main->error(Wx::gettext("Only .pl files can be executed"));
	#	}

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

	# Set up the debugger
	my $host = 'localhost';
	my $port = 12345 + int rand(1000); # TODO make this configurable?


	{
		local $ENV{PERLDB_OPTS} = "RemotePort=$host:$port";

		# Run with console Perl to prevent unexpected results under wperl
		my $perl = Padre::Perl::cperl();
		$main->run_command(qq["$perl" -d "$filename"]);
	}

	require Debug::Client;
	my $debugger = Debug::Client->new( host => $host, port => $port );
	$debugger->listen;
	$self->{_debugger_} = $debugger;

	$self->{running_file} = $filename;

	my ( $module, $file, $row, $content ) = $debugger->get;

	if ( not $self->{save}{$filename} ) {
		$self->{save}{$filename} = {};
	}
	if ( $self->{save}{$filename}{breakpoints} ) {
		foreach my $file ( keys %{ $self->{save}{$filename}{breakpoints} } ) {
			foreach my $row ( keys %{ $self->{save}{$filename}{breakpoints}{$file} } ) {

				#$self->{save}{$filename}{breakpoints}{$file}{$row};
				$self->{_debugger_}->set_breakpoint( $file, $row ); # TODO what if this fails?
				                                                    # TODO find the editor of that $file first!
				  #$editor->MarkerAdd( $row-1, Padre::Wx::MarkBreakpoint() );
			}
		}
	}

	$self->_set_debugger();

	#my @out = $debugger->get;
	#use Data::Dumper;
	#print Data::Dumper::Dumper \@out;

	#my $out = $debugger->get;
	#print $out;

	#$main->show_output(1);
	#$main->output->clear;
	#$main->output->AppendText("File: $file row: $row");

	return 1;
}

sub _set_debugger {
	my ($self) = @_;

	my $main = Padre->ide->wx->main;

	my $file   = $self->{_debugger_}{filename};
	my $row    = $self->{_debugger_}{row};
	my $editor = $main->current->editor;
	return unless $editor;
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
	$editor->MarkerAdd( $row - 1, Padre::Wx::MarkLocation() );

	#print("File: $file row: $row\n");


	my $debugger = $main->debugger;
	my $count    = $debugger->GetItemCount;
	for my $c ( 0 .. $count - 1 ) {
		my $variable = $debugger->GetItemText($c);

		#print $debugger->GetItem($c, 0)->GetText, "\n";

		my $value = eval { $self->{_debugger_}->get_value($variable) };
		if ($@) {

			#$main->error(sprintf(_T("Could not evaluate '%s'"), $text));
			#return;
		} else {
			$debugger->SetItem( $c, 1, $value );
		}
	}

	return;
}

sub debugger_is_running {
	my $self = shift;

	my $main = Padre->ide->wx->main;

	if ( not $self->{_debugger_} ) {
		$main->error( _T('Debugger not running') );
		return;
	}
	my $editor = $main->current->editor;
	return unless $editor;

	return 1;
}

sub debug_perl_remove_breakpoint {
	my $self = shift;

	return if not $self->debugger_is_running;

	my $editor = Padre::Current->editor;
	my $file   = $editor->{Document}->filename;
	my $row    = $editor->GetCurrentLine + 1;
	$self->{_debugger_}->remove_breakpoint( $file, $row );
	delete $self->{save}{ $self->{running_file} }{breakpoints}{$file}{$row};

	return;
}

sub error {
	my $self = shift;
	my $msg  = shift;

	return Padre->ide->wx->main->error($msg);
}

sub message {
	my $self = shift;
	my $msg  = shift;

	return Padre->ide->wx->main->message($msg);
}


sub debug_perl_set_breakpoint {
	my $self = shift;

	return if not $self->debugger_is_running;

	my $editor = Padre::Current->editor;

	my $file = $editor->{Document}->filename;
	my $row  = $editor->GetCurrentLine + 1;

	# TODO ask for a condition

	# TODO allow setting breakpoints even before the script and the debugger runs
	# (by saving it in the debugger configuration file?)
	if ( not $self->{_debugger_}->set_breakpoint( $file, $row ) ) {
		$self->error( sprintf( _T("Could not set breakpoint on file '%s' row '%s'"), $file, $row ) );
		return;
	}
	$editor->MarkerAdd( $row - 1, Padre::Wx::MarkBreakpoint() );
	$self->{save}{ $self->{running_file} }{breakpoints}{$file}{$row} = 1; # TODO that should be the condition I guess

	return;
}

sub debug_perl_list_breakpoints {
	my $self = shift;

	return if not $self->debugger_is_running;

	my $msg = $self->{_debugger_}->list_break_watch_action();             # LIST context crashes in Debug::Client 0.10
	$self->message($msg);

	return;
}

sub debug_perl_jumpt_to {
	my $self = shift;

	return if not $self->debugger_is_running;

	$self->_set_debugger();
	return;
}

sub debug_perl_quit {
	my $self = shift;

	return if not $self->debugger_is_running;

	my $editor = Padre::Current->editor;
	$editor->MarkerDeleteAll(Padre::Wx::MarkLocation);

	Padre->ide->wx->main->show_debugger(0);

	$self->{_debugger_}->quit;
	delete $self->{_debugger_};

	return;
}

sub debug_perl_step_in {
	my $self = shift;

	my $main = Padre->ide->wx->main;

	if ( not $self->{_debugger_} ) {
		if ( not $self->debug_perl ) {
			$main->error( _T('Debugger not running') );
			return;
		}

		# no need to make first step
		return;
	}

	my ( $module, $file, $row, $content ) = $self->{_debugger_}->step_in;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->debug_perl_quit;
		return;
	}
	$self->_set_debugger();

	return;
}

sub debug_perl_step_over {
	my $self = shift;

	my $main = Padre->ide->wx->main;

	if ( not $self->{_debugger_} ) {
		if ( not $self->debug_perl ) {
			$main->error( _T('Debugger not running') );
			return;
		}
	}

	my ( $module, $file, $row, $content ) = $self->{_debugger_}->step_over;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->debug_perl_quit;
		return;
	}
	$self->_set_debugger();

	return;
}

sub debug_perl_run_to_cursor {
	my $self = shift;

	my $main = Padre->ide->wx->main;

	my $current = $main->current;
	return $main->error("Not implemented");

	# Commented our for critic:
	#	my $file = $current->filename;
	#	my $row  = '';
	#
	#	# put a breakpoint to the cursor and then run till there
	#	$self->debug_perl_run();
}

sub debug_perl_run {
	my $self  = shift;
	my $param = shift;

	my $main = Padre->ide->wx->main;

	if ( not $self->{_debugger_} ) {
		if ( not $self->debug_perl ) {
			$main->error( _T('Debugger not running') );
			return;
		}
	}

	my ( $module, $file, $row, $content ) = $self->{_debugger_}->run($param);
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->debug_perl_quit;
		return;
	}
	$self->_set_debugger();

	return;
}


sub debug_perl_step_out {
	my $self = shift;

	my $main = Padre->ide->wx->main;

	if ( not $self->{_debugger_} ) {
		$main->error( _T('Debugger not running') );
		return;
	}

	my ( $module, $file, $row, $content ) = $self->{_debugger_}->step_out;
	if ( $module eq '<TERMINATED>' ) {
		TRACE('TERMINATED') if DEBUG;
		$self->debug_perl_quit;
		return;
	}
	$self->_set_debugger();

	return;
}


sub debug_perl_show_stack_trace {
	my $self = shift;

	return if not $self->debugger_is_running;

	my $trace = $self->{_debugger_}->get_stack_trace;
	my $str   = $trace;
	if ( ref($trace) and ref($trace) eq 'ARRAY' ) {
		$str = join "\n", @$trace;
	}
	$self->message($str);

	return;
}


sub debug_perl_show_value {
	my $self = shift;

	return if not $self->debugger_is_running;

	my $text = $self->_debug_get_variable() or return;

	my $value = eval { $self->{_debugger_}->get_value($text) };
	if ($@) {
		$self->error( sprintf( _T("Could not evaluate '%s'"), $text ) );
		return;
	}
	$self->message("$text = $value");

	return;
}

sub _debug_get_variable {
	my $self = shift;

	my $main = Padre->ide->wx->main;

	my $current = $main->current;

	return unless $current->editor;
	my $text = $current->text;
	if ( not $text or $text !~ /^[\$@%\\]/ ) {
		$main->error( sprintf( _T("'%s' does not look like a variable"), $text ) );
		return;
	}
	return $text;
}

sub debug_perl_display_value {
	my $self = shift;

	return if not $self->debugger_is_running;

	my $main     = Padre->ide->wx->main;
	my $text     = $self->_debug_get_variable() or return;
	my $debugger = $main->debugger;

	my $count = $debugger->GetItemCount;
	my $idx = $debugger->InsertStringItem( $count + 1, $text );

	#	my $value = eval { $self->{_debugger_}->get_value($text) };
	#	if ($@) {
	#		$main->error(sprintf(_T("Could not evaluate '%s'"), $text));
	#		return;
	#	} else {
	#		$debugger->SetItem( $idx, 1, $value );
	#	}

	return;
}

sub debug_perl_evaluate_expression {
	my $self = shift;

	return if not $self->debugger_is_running;

	my $main       = Padre->ide->wx->main;
	my $expression = $main->prompt(
		Wx::gettext("Expression:"),
		Wx::gettext("Expr"),
		"EVAL_EXPRESSION"
	);
	$self->{_debugger_}->execute_code($expression);

	return;
}

sub quit {
	my $self = shift;
	if ( $self->{_debugger_} ) {
		$self->debug_perl_quit;
	}
	return;
}

1;


# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
