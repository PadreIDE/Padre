package Padre::Wx::Menu::Perl;

# Fully encapsulated Perl menu

use 5.008;
use strict;
use warnings;
use List::Util      ();
use File::Spec      ();
use File::HomeDir   ();
use Params::Util    ();
use Padre::Locale   ();
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.25';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Cache the configuration
	$self->{config} = $main->config;

	# Module-Related Functions
	$self->{module} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Install Module..."),
		$self->{module}
	);

	# Install modules from CPAN
	$self->{module_install_cpan} = $self->{module}->Append( -1,
		Wx::gettext("Install CPAN Module"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{module_install_cpan},
		sub {
			$self->install_cpan($_[0]);
		},
	);

	$self->{module}->AppendSeparator;

	# Install from other places
	$self->{module_install_file} = $self->{module}->Append( -1,
		Wx::gettext("Install Local Distribution"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{module_install_file},
		sub {
			$self->install_file($_[0]);
		},
	);

	$self->{module_install_url} = $self->{module}->Append( -1,
		Wx::gettext("Install Remote Distribution"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{module_install_url},
		sub {
			$self->install_url($_[0]);
		},
	);

	$self->{module}->AppendSeparator;

	# Utility Operations
	$self->{module_open_config} = $self->{module}->Append( -1,
		Wx::gettext("Open CPAN Config File"),
	);
	Wx::Event::EVT_MENU( $main,
		$self->{module_open_config},
		sub {
			$self->open_config($_[0]);
		},
	);

	$self->AppendSeparator;





	# Perl-Specific Searches
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Find Unmatched Brace")
		),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE($doc, 'Padre::Document::Perl');
			$doc->find_unmatched_brace;
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext("Find Variable Declaration") ),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE($doc, 'Padre::Document::Perl');
			$doc->find_variable_declaration;
		},
	);

	$self->AppendSeparator;





	# Perl-Specific Refactoring
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Lexically Rename Variable")
		),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE($doc, 'Padre::Document::Perl');
			my $dialog = Padre::Wx::History::TextDialog->new(
				$_[0],
				Wx::gettext("Replacement"),
				Wx::gettext("Replacement"),
				'$foo',
			);
			if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
				return;
			}
			my $replacement = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $replacement;

			$doc->lexical_variable_replacement($replacement);
		},
	);

	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext("Vertically Align Selected")
		),
		sub {
			my $editor = $_[0]->current->editor or return;

			# Get the selected lines
			my $begin = $editor->LineFromPosition( $editor->GetSelectionStart );
			my $end   = $editor->LineFromPosition( $editor->GetSelectionEnd   );
			if ( $begin == $end ) {
				$_[0]->error(Wx::gettext("You must select a range of lines"));
				return;
			}
			my @line  = ( $begin .. $end );
			my @text  = ();
			foreach ( @line ) {
				my $x = $editor->PositionFromLine($_);
				my $y = $editor->GetLineEndPosition($_);
				push @text, $editor->GetTextRange($x, $y);
			}

			# Get the align character from the selection start
			# (which must be a non-whitespace non-word character)
			my $start = $editor->GetSelectionStart;
			my $c     = $editor->GetTextRange($start, $start + 1);
			unless ( defined $c and $c =~ /^[^\s\w]$/ ) {
				$_[0]->error(Wx::gettext("First character of selection must be a non-word character to align"));
			}

			# Locate the position of the align character,
			# and the position of the earliest whitespace before it.
			my $qc       = quotemeta $c;
			my @position = ();
			foreach ( @text ) {
				if ( /^(.+?)(\s*)$qc/ ) {
					push @position, [ length("$1"), length("$2") ];
				} else {
					# This line is not a member of the align set
					push @position, undef;
				}
			}

			# Find the latest position of the starting whitespace.
			my $longest = List::Util::max map { $_->[0] } grep { $_ } @position;

			# Now lets line them up
			$editor->BeginUndoAction;
			foreach ( 0 .. $#line ) {
				next unless $position[$_];
				my $spaces = $longest
					- $position[$_]->[0]
					- $position[$_]->[1]
					+ 1;
				if ( $_ == 0 ) {
					$start = $start + $spaces;
				}
				my $insert = $editor->PositionFromLine($line[$_]) + $position[$_]->[0];
				if ( $spaces > 0 ) {
					$editor->InsertText( $insert, ' ' x $spaces );
				} elsif ( $spaces < 0 ) {
					$editor->SetSelection($insert, $insert - $spaces);
					$editor->ReplaceSelection('');
				}
			}
			$editor->EndUndoAction;

			# Move the selection to the new position
			$editor->SetSelection( $start, $start );

			return;
		},
	);

	$self->AppendSeparator;





	# Perl-Specific Options
	$self->{ppi_highlight} = $self->AppendCheckItem( -1,
		Wx::gettext("Use PPI Syntax Highlighting")
	);
	Wx::Event::EVT_MENU( $main,
		$self->{ppi_highlight},
		sub {
			# Update the saved config setting
			my $config = Padre->ide->config;
			$config->set( ppi_highlight => $_[1]->IsChecked ? 1 : 0 );

			# Refresh the menu (and MIME_LEXER hook)
			$self->refresh;

			# Update the colourise for each Perl editor
			# TODO try to delay the actual color updating for the
			# pages that are not in focus till they get in focus
			foreach my $editor ( $_[0]->editors ) {
				my $doc = $editor->{Document};
				next unless $doc->isa('Padre::Document::Perl');
				$editor->SetLexer( $doc->lexer );
				if ( $config->ppi_highlight ) {
					$doc->colorize;
				} else {
					$doc->remove_color;
					$editor->Colourise( 0, $editor->GetLength );
				}
			}

			return;
		}
	);

	# Make it easier to access stack traces
	$self->{run_stacktrace} = $self->AppendCheckItem( -1,
		Wx::gettext("Run Scripts with Stack Trace")
	);	
	Wx::Event::EVT_MENU( $main, $self->{run_stacktrace},
		sub {
			# Update the saved config setting
			my $config = Padre->ide->config;
			$config->set( run_stacktrace => $_[1]->IsChecked ? 1 : 0 );
			$self->refresh;
		}
	);

	return $self;
}

sub refresh {
	my $self   = shift;
	my $config = $self->{config};

	$self->{ppi_highlight}->Check( $config->ppi_highlight );
	$self->{run_stacktrace}->Check( $config->run_stacktrace );

	no warnings 'once'; # TODO eliminate?
	$Padre::Document::MIME_LEXER{'application/x-perl'} = 
		$config->ppi_highlight
			? Wx::wxSTC_LEX_CONTAINER
			: Wx::wxSTC_LEX_PERL;
}





#####################################################################
# Menu Event Methods

sub install_file {
	# TODO: supidly duplicated to avoid warning
	$DB::single = $DB::single = 1;
	my $self = shift;
	my $main = shift;

	# Ask what we should install
	my $dialog = Wx::FileDialog->new(
		$main,
		Wx::gettext("Select distribution to install"),
		'', # Default directory
		'', # Default file
		undef,
		Wx::wxFD_OPEN
		| Wx::wxFD_FILE_MUST_EXIST
	);
	$dialog->CentreOnParent;
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error("Did not provide a distribution");
		return;
	}

	return;
}

sub install_url {
	my $self = shift;
	my $main = shift;

	# Ask what we should install
	my $dialog = Wx::TextEntryDialog->new(
		$main,
		"Enter URL to install\ne.g. http://svn.ali.as/cpan/releases/Config-Tiny-2.00.tar.gz",
		"pip",
		'',
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error("Did not provide a distribution");
		return;
	}

	# Execute the command
	my $perl   = Padre->perl_interpreter;
	my $dir    = File::Basename::dirname( $perl );
	my $pip    = File::Spec->catfile( $dir, 'pip' );
	unless ( -f $pip ) {
		$main->error("pip is unexpectedly not installed");
		return;
	}

	# If this is the first time a command has been run,
	# set up the ProcessStream bindings.
	unless ( $Wx::Perl::ProcessStream::VERSION ) {
		require Wx::Perl::ProcessStream;
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDOUT(
			$main,
			sub {
				$_[1]->Skip(1);
				$_[0]->output->AppendText( $_[1]->GetLine . "\n" );
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDERR(
			$main,
			sub {
				$_[1]->Skip(1);
				$_[0]->output->AppendText( $_[1]->GetLine . "\n" );
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_EXIT(
			$main,
			sub {
				$_[1]->Skip(1);
				$_[1]->GetProcess->Destroy;
				$main->menu->run->enable;
			},
		);
	}

	# Prepare the output window
	$main->show_output(1);
	$main->output->clear;
	$main->menu->run->disable;

	# Run with the same Perl that launched Padre
	my $cmd = qq{"$perl" "pip" "$string"};
	local $ENV{AUTOMATED_TESTING} = 1;
	Wx::Perl::ProcessStream->OpenProcess( $cmd, 'CPAN_mod', $main );

	return;
}

sub install_cpan {
	my $self = shift;
	my $main = shift;

	# Ask for the module name	
	require Padre::Wx::History::TextDialog;
	my $dialog = Padre::Wx::History::TextDialog->new(
		$main,
		"Module Name:\neg: Perl::Critic",
		'Install Module',
		'CPAN_INSTALL_MODULE',
	);
	my $result = $dialog->ShowModal;
	my $module = $dialog->GetValue;

	# Handle aborted installs
	$dialog->Destroy;
	if ( $result == Wx::wxID_CANCEL ) {
		return;
	}
	unless ( defined $module ) {
		return;
	}
	$module =~ s/^\s+//g;
	$module =~ s/\s+$//g;
	unless ( $module ne '' ) {
		return;
	}

	# Validation?

	# If this is the first time a command has been run,
	# set up the ProcessStream bindings.
	unless ( $Wx::Perl::ProcessStream::VERSION ) {
		require Wx::Perl::ProcessStream;
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDOUT(
			$main,
			sub {
				$_[1]->Skip(1);
				$_[0]->output->AppendText( $_[1]->GetLine . "\n" );
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDERR(
			$main,
			sub {
				$_[1]->Skip(1);
				$_[0]->output->AppendText( $_[1]->GetLine . "\n" );
				return;
			},
		);
		Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_EXIT(
			$main,
			sub {
				$_[1]->Skip(1);
				$_[1]->GetProcess->Destroy;
				$main->menu->run->enable;
			},
		);
	}

	# Prepare the output window
	$main->show_output(1);
	$main->output->clear;
	$main->menu->run->disable;

	# Run with the same Perl that launched Padre
	my $perl = Padre->perl_interpreter;
	my $cmd = qq{"$perl" "-MCPAN" "-e" "install $module"};
	local $ENV{AUTOMATED_TESTING} = 1;
	Wx::Perl::ProcessStream->OpenProcess( $cmd, 'CPAN_mod', $main );

	return;
}

sub open_config {
	my $self = shift;
	my $main = shift;

	# Locate the CPAN config file(s)
	require CPAN;
	my $default_dir = $INC{'CPAN.pm'};
	$default_dir =~ s/\.pm$//is; # remove .pm

	# Load the main config first
	my $core = File::Spec->catfile($default_dir, 'Config.pm');
	if ( -e $core ) {
		$main->setup_editors($core);
		return;
	}

	# Fallback to a personal config
	my $user = File::Spec->catfile(
		File::HomeDir->my_home,
		'.cpan', 'CPAN', 'MyConfig.pm'
	);
	if ( -e $user ) {
		$main->setup_editors($user);
		return;
	}

	$main->error("Failed to find your CPAN configuration");
}

1;
# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
