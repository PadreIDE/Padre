package Padre::Document::Perl::Starter;

=pod

=head1 NAME

Padre::Document::Perl::Starter - Starter module for Perl 5 documents

=head1 DESCRIPTION

B<Padre::Document::Perl::Starter> provides support for generating Perl 5
documents and projects of various types.

=head1 METHODS

=cut

use 5.010;
use strict;
use warnings;
use Params::Util                          ();
use Padre::Template                       ();
use Padre::Document::Perl::Starter::Style ();

our $VERSION = '1.00';





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
		main  => shift,
		style => Padre::Document::Perl::Starter::Style->new(@_),
	}, $class;
}

=pod

=head2 style

The C<style> accessor returns the default code style for modules as a
L<Padre::Document::Perl::Starter::Style> object. Any style values provided
to a specific create method will override these defaults.

=cut

sub style {
	$_[0]->{style};
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
	shift->create('perl5/script_pl.tt', @_);
}

sub generate_script {
	shift->generate('perl5/script_pl.tt', @_);
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
	unless ( defined Params::Util::_STRING($param{module}) ) {
		$param{module} = $self->main->prompt(
			Wx::gettext('Module Name:'),
			Wx::gettext('New Module'),
		);
		unless ( defined Params::Util::_STRING($param{module}) ) {
			return;
		}
	}

	$self->create('perl5/module_pm.tt', %param);
}

sub generate_module {
	my $self  = shift;
	my %param = @_;

	# Abort if we don't have a module name
	unless ( defined Params::Util::_STRING($param{module}) ) {
		return;
	}

	$self->generate('perl5/module_pm.tt', %param);
}

=pod

=head2 create_test

    $starter->create_test;

Create a new empty Perl 5 test, applying the user's style preferences if
possible.

=cut

sub create_test {
	shift->create('perl5/test_t.tt', @_);
}

sub generate_test {
	shift->generate('perl5/test_t.tt', @_);
}

=pod

=head2 create_test_compile

    $starter->create_text_compile;

Create a new empty Perl 5 test for compilation testing of all the code in your
project, so that further tests can use your modules as normal without doing any
load testing of their own.

=cut

sub create_text_compile {
	my $self = shift;
	my $code = $self->generate_test_compile(@_) or return undef;

	$self->new_document($code);
}

sub generate_test_compile {
	my $self  = shift;
	my %param = @_;

	# Get the style and module name from the current project
	if ( Params::Util::_INSTANCE($param{project}, 'Padre::Project::Perl') ) {
		$param{style}  ||= $param{project};
		$param{module} ||= $param{project}->module or return undef;	
	}

	# We must have a module name
	unless ( Params::Util::_CLASS($param{module}) ) {
		return undef;
	}

	$self->generate( 'perl5/01_compile_t.tt', %param );
}





######################################################################
# Support Methods

sub create {
	my $self = shift;
	my $code = $self->generate(@_) or return undef;

	$self->new_document($code);
}

sub generate {
	my $self = shift;
	my $name  = shift;
	my %param = $self->params(@_);
	my $code  = Padre::Template->render($name, %param);

	$self->tidy($code);
}

sub params {
	my $self  = shift;
	my %param = @_;

	# Inheriting from a project means inheriting from the headline file
	if ( Params::Util::_INSTANCE($param{style}, 'Padre::Project::Perl') ) {
		$param{style} = $param{style}->headline_path;
	}

	# Inherit style from an existing document
	if ( Params::Util::_INSTANCE($param{style}, 'Padre::Document::Perl') ) {
		$param{style} = Padre::Document::Perl::Starter::Style->from_document(
			$param{style},
			$self->{style},
		);
	}

	# Inherit style from a file on disk
	if ( Params::Util::_STRING($param{style}) ) {
		$param{style} = Padre::Document::Perl::Starter::Style->from_file(
			$param{style},
			$self->{style},
		);
	}

	# Apply default style if we have nothing more specific
	unless ( Params::Util::_INSTANCE($param{style}, 'Padre::Document::Perl::Starter::Style') ) {
		$param{style} = $self->{style};
	}

	return %param;
}

sub tidy {
	my $self = shift;
	my $code = shift;

	# Remove multiple blank lines
	$code =~ s/\n{3,}/\n\n/sg;

	# Remove spaces between successive use statements to create use blocks
	$code =~ s/(?<=\n)(use\b\N+)\n+(?=use\b)/$1\n/g;

	return $code;
}

sub new_document {
	$_[0]->main->new_document_from_string( $_[1] => 'application/x-perl' );
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
