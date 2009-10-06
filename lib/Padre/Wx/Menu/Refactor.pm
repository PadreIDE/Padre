package Padre::Wx::Menu::Refactor;

# Fully encapsulated Refactor menu

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

our $VERSION = '0.47';
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

	$self->{extract_subroutine} = $self->add_menu_item(
		$self,
		name       => 'perl.extract_subroutine',
		label      => Wx::gettext('Extract Subroutine'),
		menu_event => sub {
			my $doc    = $_[0]->current->document;
			my $editor = $doc->editor;
			my $code   = $editor->GetSelectedText();
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				Wx::gettext("Please enter a name for the new subroutine"),
				Wx::gettext("New Subroutine Name"),
				'$foo',
			);
			return if $dialog->ShowModal == Wx::wxID_CANCEL;
			my $newname = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $newname;

			require Devel::Refactor;
			my $refactory = Devel::Refactor->new;
			my ( $new_sub_call, $new_code ) = $refactory->extract_subroutine( $newname, $code, 1 );
			$editor->BeginUndoAction(); # do the edit atomically
			$editor->ReplaceSelection($new_sub_call);
			$editor->DocumentEnd();     # TODO: find a better place to put the new subroutine
			$editor->AddText($new_code);
			$editor->EndUndoAction();
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


	return $self;
}

sub refresh {
	my $self    = shift;
	my $current = _CURRENT(@_);
	my $config  = $current->config;
	my $perl    = !!( _INSTANCE( $current->document, 'Padre::Document::Perl' ) );

	$self->{rename_variable}->Enable($perl);
	$self->{introduce_temporary}->Enable($perl);
	$self->{extract_subroutine}->Enable($perl);

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
