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

our $VERSION = '0.29';
use base 'Padre::Wx::Menu';



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
# Move of stacktrace to Run
#	# Make it easier to access stack traces
#	$self->{run_stacktrace} = $self->AppendCheckItem( -1,
#		Wx::gettext("Run Scripts with Stack Trace")
#	);	
#	Wx::Event::EVT_MENU( $main, $self->{run_stacktrace},
#		sub {
#			# Update the saved config setting
#			my $config = Padre->ide->config;
#			$config->set( run_stacktrace => $_[1]->IsChecked ? 1 : 0 );
#			$self->refresh;
#		}
#	);

	$self->{autocomplete_brackets} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Automatic bracket completion")
	);
	Wx::Event::EVT_MENU( $main, $self->{autocomplete_brackets},
		sub {
			# Update the saved config setting
			my $config = Padre->ide->config;
			$config->set( autocomplete_brackets => $_[1]->IsChecked ? 1 : 0 );
		}
	);

	return $self;
}

sub refresh {
	my $self   = shift;
	my $config = $self->{config};

	$self->{ppi_highlight}->Check( $config->ppi_highlight );
	#$self->{run_stacktrace}->Check( $config->run_stacktrace );
	$self->{autocomplete_brackets}->Check( $config->autocomplete_brackets );

	no warnings 'once'; # TODO eliminate?
	$Padre::Document::MIME_LEXER{'application/x-perl'} = 
		$config->ppi_highlight
			? Wx::wxSTC_LEX_CONTAINER
			: Wx::wxSTC_LEX_PERL;
}


1;
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
