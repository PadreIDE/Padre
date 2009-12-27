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

use Padre::Action ();
use Padre::Current qw{_CURRENT};
use Padre::Locale   ();
use Padre::Util     ('_T');
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.53';

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
		name        => 'perl.rename_variable',
		need_editor => 1,
		label       => _T('Lexically Rename Variable'),
		comment     => _T('Prompt for a replacement variable name and replace all occurrance of this variable'),
		menu_event  => sub {
			my $doc = $_[0]->current->document or return;
			return unless $doc->can('lexical_variable_replacement');
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				_T("Replacement"),
				_T("Replacement"),
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
		name        => 'perl.extract_subroutine',
		need_editor => 1,
		label       => _T('Extract Subroutine'),
		comment     => _T(
			      'Cut the current selection and create a new sub from it. '
				. 'A call to this sub is added in the place where the selection was.'
		),
		menu_event => sub {
			my $doc = $_[0]->current->document or return;
			return unless $doc->can('extract_subroutine');

			#my $editor = $doc->editor;
			#my $code   = $editor->GetSelectedText();
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				_T("Please enter a name for the new subroutine"),
				_T("New Subroutine Name"),
				'$foo',
			);
			return if $dialog->ShowModal == Wx::wxID_CANCEL;
			my $newname = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $newname;
			$doc->extract_subroutine($newname);

		},
	);

	Padre::Action->new(
		name        => 'perl.introduce_temporary',
		need_editor => 1,
		label       => _T('Introduce Temporary Variable'),
		comment     => _T('Assign the selected expression to a newly declared variable'),
		menu_event  => sub {
			my $doc = $_[0]->current->document or return;
			return unless $doc->can('introduce_temporary_variable');
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				_T("Variable Name"),
				_T("Variable Name"),
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
