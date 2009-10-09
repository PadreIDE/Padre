package Padre::Action::Refactor;

# Actions for refactoring

=pod

=head1 NAME

Padre::Action::Refactor is a outsourced module. It creates Actions for
various helper function for refactoring.

=cut

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

#####################################################################
# Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Cache the configuration
	$self->{config} = Padre->ide->config;

	# Perl-Specific Refactoring
	Padre::Action->new(
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

	Padre::Action->new(
		name       => 'perl.extract_subroutine',
		label      => Wx::gettext('Extract Subroutine'),
		comment	   => 'Cut the current selection and create a new sub from it. '.
		              'A call to this sub is added in the place where the selection was.',
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

	Padre::Action->new(
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

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
