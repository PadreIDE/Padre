package Padre::Document::Perl::Starter;

=pod

=head1 NAME

Padre::Document::Perl::Starter - Starter module for Perl 5 documents

=head1 DESCRIPTION

B<Padre::Document::Perl::Starter> provides support for generating Perl 5
documents and projects of various types.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Template ();

our $VERSION = '0.94';





######################################################################
# Constructor and Accessors

=pod

=head2 new

  my $starter = Padre::Document::Perl::Starter->new($main);

The C<new> constructor creates a new code generator, taking the main
window object as a parameter.

=cut

sub new {
	my $class = shift;
	return bless {
		main => shift,
	}, $class;
}

=pod

=head2 main

The C<main> accessor returns the main window object.

=cut

sub main {
	$_[0]->{main};
}

=pod

=head2 current

The C<current> accessor returns a C<Padre::Current> object for the current
context.

=cut

sub current {
	$_[0]->{main}->current;
}





######################################################################
# Document Starters

=pod

=head2 create_script

    $starter->create_script;

Create a new blank Perl 5 script, applying the user's style preferences if
possible.

=cut

sub create_script {
	my $self = shift;
	my $code = Padre::Template->render('perl5/script_pl.tt');
	$self->main->new_document_from_string(
		$code => 'application/x-perl',
	);
}

=pod

=head2 create_module

    $starter->create_module( module => $package );

Create a new empty Perl 5 module, applying the user's style preferences if
possible. If passed a package name, that module will be created.

If no package name is provided, the user will be asked for the name to use.

=cut

sub create_module {
	my $self   = shift;
	my %param  = @_;
	my $module = $param{module};

	# Ask for a module name if one is not provided
	unless ( defined Params::Util::_STRING($module) ) {
		$module = $self->main->prompt(
			Wx::gettext('Module Name:'),
			Wx::gettext('New Module'),
		);
	}

	# If we still don't have a module name abort
	unless ( defined Params::Util::_STRING($module) ) {
		return;
	}

	# Generate the code from the module template
	my $code = Padre::Template->render(
		'perl5/module_pm.tt',
		module => $module,
	);

	# Show the new file in a new editor window
	$self->main->new_document_from_string(
		$code => 'application/x-perl',
	);
}

=pod

=head2 create_test

    $starter->create_test;

Create a new empty Perl 5 test, applying the user's style preferences if
possible.

=cut

sub create_test {
	my $self = shift;
	my $code = Padre::Template->render('perl5/test_t.tt');
	$self->main->new_document_from_string(
		$code => 'application/x-perl',
	);
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
