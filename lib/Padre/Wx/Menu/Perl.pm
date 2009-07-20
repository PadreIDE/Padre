package Padre::Wx::Menu::Perl;

# Fully encapsulated Perl menu

use 5.008;
use strict;
use warnings;
use List::Util    ();
use File::Spec    ();
use File::HomeDir ();
use Params::Util qw{_INSTANCE};
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Locale   ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.40';
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
	$self->{config} = Padre->ide->config;

	# Perl-Specific Searches
	$self->{find_brace} = $self->Append(
		-1,
		Wx::gettext("Find Unmatched Brace")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{find_brace},
		sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_unmatched_brace;
		},
	);

	$self->{find_variable} = $self->Append(
		-1,
		Wx::gettext("Find Variable Declaration")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{find_variable},
		sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_variable_declaration;
		},
	);

	$self->AppendSeparator;

	# Perl-Specific Refactoring
	$self->{rename_variable} = $self->Append(
		-1,
		Wx::gettext("Lexically Rename Variable")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{rename_variable},
		sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				Wx::gettext("Replacement"),
				Wx::gettext("Replacement"),
				'$foo',
			);
			return if $dialog->ShowModal == Wx::wxID_CANCEL;
			my $replacement = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $replacement;
			$doc->lexical_variable_replacement($replacement);
		},
	);

	$self->{introduce_temporary} = $self->Append(
		-1,
		Wx::gettext("Introduce Temporary Variable")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{introduce_temporary},
		sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				Wx::gettext("Variable Name"),
				Wx::gettext("Variable Name"),
				'$tmp',
			);
			return if $dialog->ShowModal == Wx::wxID_CANCEL;
			my $replacement = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $replacement;
			$doc->introduce_temporary_variable($replacement);
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
	my $self    = shift;
	my $current = _CURRENT(@_);
	my $config  = $current->config;
	my $perl    = !!( _INSTANCE( $current->document, 'Padre::Document::Perl' ) );

	# Disable document-specific entries if we are in a Perl project
	# but not in a Perl document.
	$self->{find_brace}->Enable($perl);
	$self->{find_variable}->Enable($perl);
	$self->{rename_variable}->Enable($perl);

	# Apply config-driven state
	$self->{autocomplete_brackets}->Check( $config->autocomplete_brackets );

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
