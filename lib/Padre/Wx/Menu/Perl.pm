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

our $VERSION = '0.42';
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
	$self->{find_brace} = $self->add_menu_item(
		$self,
		name       => 'perl.find_brace',
		label      => Wx::gettext('Find Unmatched Brace'),
		menu_event => sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_unmatched_brace;
		},
	);

	$self->{find_variable} = $self->add_menu_item(
		$self,
		name       => 'perl.find_variable',
		label      => Wx::gettext('Find Variable Declaration'),
		menu_event => sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_variable_declaration;
		},
	);

	$self->AppendSeparator;

	# Perl-Specific Refactoring
	$self->{rename_variable} = $self->add_menu_item(
		$self,
		name       => 'perl.rename_variable',
		label      => Wx::gettext('Lexically Rename Variable'),
		menu_event => sub {
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

	$self->{introduce_temporary} = $self->add_menu_item(
		$self,
		name       => 'perl.introduce_temporary',
		label      => Wx::gettext('Introduce Temporary Variable'),
		menu_event => sub {
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

	$self->add_menu_item(
		$self,
		name       => 'perl.vertically_align_selected',
		label      => Wx::gettext('Vertically Align Selected'),
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$editor->vertically_align;
		},
	);

	$self->add_menu_item(
		$self,
		name       => 'perl.newline_keep_column',
		label      => Wx::gettext('Newline same column'),
		shortcut   => 'Ctrl-Enter',
		menu_event => sub {
			my $document = $_[0]->current->document or return;
			return unless _INSTANCE( $document, 'Padre::Document::Perl' );
			$document->newline_keep_column;
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

	$self->{autocomplete_brackets} = $self->add_checked_menu_item(
		$self,
		name       => 'perl.autocomplete_brackets',
		label      => Wx::gettext('Automatic bracket completion'),
		menu_event => sub {

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
