package Padre::Wx::Command;

# Class for the command window at the bottom of Padre.
# This currently has very little customisation code in it,
# but that will change in future.

use 5.008;
use strict;
use warnings;
use utf8;
use Encode                ();
use File::Spec            ();
use Params::Util          ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::SplitterWindow
};


######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;

	my $self = $class->SUPER::new(
		$panel, -1, Wx::DefaultPosition, Wx::DefaultSize,
		Wx::NO_FULL_REPAINT_ON_RESIZE | Wx::CLIP_CHILDREN
	);

	my $output = Wx::TextCtrl->new(
		$self, -1, "", Wx::DefaultPosition, Wx::DefaultSize,
		Wx::TE_READONLY | Wx::TE_MULTILINE | Wx::NO_FULL_REPAINT_ON_RESIZE
	);

	my $input = Wx::TextCtrl->new(
		$self, -1, "", Wx::DefaultPosition, Wx::DefaultSize,
		Wx::NO_FULL_REPAINT_ON_RESIZE | Wx::TE_PROCESS_ENTER
	);

	$self->{_output_} = $output;
	$self->{_input_}  = $input;

	# Do custom start-up stuff here
	#$self->clear;
	#$self->set_font;

	# Moves the focus the input window but does not allow selecting text in the output window
	#Wx::Event::EVT_SET_FOCUS( $output, sub { $input->SetFocus; } );

	Wx::Event::EVT_TEXT_ENTER(
		$main, $input,
		sub {
			$self->text_entered(@_);
		}
	);
	Wx::Event::EVT_KEY_UP( $input, sub { $self->key_up(@_) } );

	my $height = $main->{bottom}->GetSize->GetHeight;

	#print "Height: $height\n";
	#print $self->GetSize->GetHeight, "\n"; # gives 20 on startup?
	$self->SplitHorizontally( $output, $input, $height - 120 ); ## TODO ???
	$input->SetFocus;

	$self->{_history_} = Padre::DB::History->recent('commands') || [];

	#$self->{_history_pointer_} = @{ $self->{_history_} } - 1;

	$self->{_output_}->WriteText(
		Wx::gettext(
			"Experimental feature. Type '?' at the bottom of the page to get list of commands. If it does not work, blame szabgab.\n\n"
		)
	);

	return $self;
}


######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	Wx::gettext('Command');
}

sub view_close {
	shift->main->show_command(0);
}



######################################################################
# Event Handlers

sub text_entered {
	my ( $self, $main, $event ) = @_;

	my $text = $self->{_input_}->GetRange( 0, $self->{_input_}->GetLastPosition );
	$self->{_input_}->Clear;
	$self->out(">> $text\n");
	my %commands = (
		':e filename'        => 'Open file',
		':! cmd'             => 'Run command in shell',
		'?'                  => 'This help',
		':history'           => 'History of all the command',
		':padre cmd'         => 'Execute cmd withing the current Padre process',
		':keycatcher Number' => 'Turn on catching keyboard for a single event (defaults to 2)',
	);

	push @{ $self->{_history_} }, $text;
	Padre::DB::History->create(
		type => 'commands',
		name => $text,
	);

	#$self->{_history_pointer_} = @{ $self->{_history_} } - 1;
	if ( $text eq '?' ) {
		foreach my $cmd ( sort keys %commands ) {
			$self->outn("$cmd    - $commands{$cmd}");
		}
	} elsif ( $text eq ':history' ) {
		foreach my $cmd ( @{ $self->{_history_} } ) {
			$self->outn($cmd);
		}
	} elsif ( $text =~ m/^:keycatcher(\s+(\d+))?\s*$/ ) {
		$self->{_keycatcher_} = $2 || 2;
	} elsif ( $text =~ /^:e\s+(.*?)\s*$/ ) {
		my $path = $1;
		if ( not -e $path ) {
			$self->outn("File ($path) does not exist");
		} elsif ( not -f $path ) {
			$self->outn("($path) is not a file");
		} else {
			$main->setup_editors($path);
		}
	} elsif ( $text =~ /^:!\s*(.*?)\s*$/ ) {

		# TODO: what about long running commands?
		my $cmd = $1;

		# TODO: when reqire and import is used it blows up with
		# Can't call method "capture_merged" without a package or object reference at
		# so we "use" it now
		#require Capture::Tiny;
		#import Capture::Tiny qw(capture_merged);
		use Capture::Tiny qw(capture_merged);
		my $out = capture_merged {
			system($cmd);
		};
		if ( defined $out ) {
			$self->out($out);
		}
	} elsif ( $text =~ m/^:padre\s+(.*?)\s*$/ ) {
		my $ret;
		my $out = capture_merged {
			$ret = eval $1;
		};
		my $err = $@;
		if ( defined $out and $out ne '' ) {
			$self->outn($out);
		}
		if ( defined $ret and $ret ne '' ) {
			$self->outn($ret);
		}
		if ($err) {
			$self->outn($err);
		}
	} else {
		$self->outn("Invalid command");
	}

	return;
}

sub key_up {
	my ( $self, $input, $event ) = @_;

	#print $self;
	#print $event;
	my $mod = $event->GetModifiers || 0;
	my $code = $event->GetKeyCode;

	if ( $self->{_keycatcher_} ) {
		$self->{_keycatcher_}--;
		$self->outn("Mode: $mod  Code: $code");
	}

	my $text = $self->{_input_}->GetRange( 0, $self->{_input_}->GetLastPosition );
	if ( not defined $text or $text eq '' ) {
		delete $self->{_history_pointer_};
	}
	my $new_text;
	if ( $mod == 0 and $code == 9 ) { # TAB
		                              #print "Text: $text\n";
		require Padre::Util::CommandLine;
		$new_text = Padre::Util::CommandLine::tab($text);
	} elsif ( $mod == 0 and $code == 317 ) { # Down
		return if not @{ $self->{_history_} };
		if ( not defined $self->{_history_pointer_} ) {
			$self->{_history_pointer_} = 0;
		} else {
			$self->{_history_pointer_}++;
			if ( $self->{_history_pointer_} >= @{ $self->{_history_} } ) {
				$self->{_history_pointer_} = 0;
			}
		}
		$new_text = $self->{_history_}[ $self->{_history_pointer_} ];
	} elsif ( $mod == 0 and $code == 315 ) { # Up
		return if not @{ $self->{_history_} };
		if ( not defined $self->{_history_pointer_} ) {
			$self->{_history_pointer_} = @{ $self->{_history_} } - 1;
		} else {
			$self->{_history_pointer_}--;
		}
		if ( $self->{_history_pointer_} < 0 ) {
			$self->{_history_pointer_} = @{ $self->{_history_} } - 1;
		}
		$new_text = $self->{_history_}[ $self->{_history_pointer_} ];
	} elsif ( $mod == 2 and $code == 85 ) {  # Ctrl-u
		$new_text = '';
	} else {
		return;
	}

	#print "New text: $new_text\n";
	if ( defined $new_text ) {
		$self->{_input_}->Clear;
		$self->{_input_}->WriteText($new_text);
	}

}

sub out {
	my ( $self, $text ) = @_;
	$self->{_output_}->WriteText($text);
}

sub outn {
	my ( $self, $text ) = @_;
	$self->{_output_}->WriteText("$text\n");
}


#####################################################################
# General Methods

sub select {
	my $self   = shift;
	my $parent = $self->GetParent;
	$parent->SetSelection( $parent->GetPageIndex($self) );
	return;
}

sub clear {
	my $self = shift;

	#$self->SetBackgroundColour('#FFFFFF');
	#$self->Remove( 0, $self->GetLastPosition );
	#$self->Refresh;
	return 1;
}


sub relocale {

	# do nothing
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
