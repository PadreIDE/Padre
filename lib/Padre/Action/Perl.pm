package Padre::Action::Perl;

# Actions for Perl

=pod

=head1 NAME

Padre::Action::Perl is a outsourced module. It creates Actions for
developing Perl files.

=cut


use 5.008;
use strict;
use warnings;
use List::Util    ();
use File::Spec    ();
use File::HomeDir ();
use Params::Util qw{_INSTANCE};
use Padre::Locale ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.49';
our @ISA     = 'Padre::Wx::Menu';

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Cache the configuration
	$self->{config} = Padre->ide->config;

	# Perl-Specific Searches
	Padre::Action->new(
		name       => 'perl.beginner_check',
		label      => Wx::gettext('Check for common (beginner) errors'),
		menu_event => sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->beginner_check;
		},
	);

	Padre::Action->new(
		name       => 'perl.find_brace',
		label      => Wx::gettext('Find Unmatched Brace'),
		comment    => Wx::gettext('Searches the source code for brackets with lack a matching (opening/closing) part.'),
		menu_event => sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_unmatched_brace;
		},
	);

	Padre::Action->new(
		name       => 'perl.find_variable',
		label      => Wx::gettext('Find Variable Declaration'),
		menu_event => sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_variable_declaration;
		},
	);

	Padre::Action->new(
		name       => 'perl.find_method',
		label      => Wx::gettext('Find Method Declaration'),
		menu_event => sub {
			my $doc = $_[0]->current->document;
			return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
			$doc->find_method_declaration;
		},
	);

	Padre::Action->new(
		name       => 'perl.vertically_align_selected',
		label      => Wx::gettext('Vertically Align Selected'),
		comment    => Wx::gettext('Align a selection of text to the same left column.'),
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$editor->vertically_align;
		},
	);

	Padre::Action->new(
		name    => 'perl.newline_keep_column',
		label   => Wx::gettext('Newline same column'),
		comment => Wx::gettext(
			'Like pressing ENTER somewhere on a line but use the current position as ident for the new line.'),
		shortcut   => 'Ctrl-Enter',
		menu_event => sub {
			my $document = $_[0]->current->document or return;
			return unless _INSTANCE( $document, 'Padre::Document::Perl' );
			$document->newline_keep_column;
		},
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

	Padre::Action->new(
		menu_method => 'AppendCheckItem',
		name        => 'perl.autocomplete_brackets',
		label       => Wx::gettext('Automatic bracket completion'),
		menu_event  => sub {

			# Update the saved config setting
			my $config = Padre->ide->config;
			$config->set( autocomplete_brackets => $_[1]->IsChecked ? 1 : 0 );
		}
	);

	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
