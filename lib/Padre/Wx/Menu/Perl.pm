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

our $VERSION = '0.33';
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
	Wx::Event::EVT_MENU(
		$main,
		$self->Append(
			-1,
			Wx::gettext("Find Unmatched Brace")
		),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_unmatched_brace;
		},
	);

	Wx::Event::EVT_MENU(
		$main,
		$self->Append( -1, Wx::gettext("Find Variable Declaration") ),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_variable_declaration;
		},
	);

	$self->AppendSeparator;

	# Perl-Specific Refactoring
	Wx::Event::EVT_MENU(
		$main,
		$self->Append(
			-1,
			Wx::gettext("Lexically Rename Variable")
		),
		sub {
			my $doc = $_[0]->current->document;
			return unless Params::Util::_INSTANCE( $doc, 'Padre::Document::Perl' );
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

	Wx::Event::EVT_MENU(
		$main,
		$self->Append(
			-1,
			Wx::gettext("Vertically Align Selected")
		),
		sub {
			my $editor = $_[0]->current->editor or return;
			$editor->vertically_align;
		},
	);

	$self->AppendSeparator;

	# Perl-Specific Options
	$self->{ppi_highlight} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Use PPI Syntax Highlighting")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{ppi_highlight},
		sub {
			$_[0]->set_ppi_highlight($_[1]->IsChecked ? 1 : 0);
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
	Wx::Event::EVT_MENU(
		$main,
		$self->{autocomplete_brackets},
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

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
