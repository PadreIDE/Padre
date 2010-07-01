package Padre::Task::ErrorList;

use 5.008;
use strict;
use warnings;
use Padre::Task ();

our $VERSION = '0.66';
our @ISA     = 'Padre::Task';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->{data}     ||= '';
	$self->{cur_lang} ||= '';
	$self->{old_lang} ||= '';
	return $self;
}

sub run {
	my $self = shift;

	# Shortcut if nothing to do.
	# TODO: Make sure this never happens, then remove the code
	if ( $self->{old_lang} eq $self->{cur_lang} ) {
		return 1;
	}

	# Build the parser
	require Parse::ErrorString::Perl;
	my $parser =
		$self->{cur_lang}
		? Parser::ErrorString::Perl->new(
		lang => $self->{cur_lang},
		)
		: Parser::ErrorString::Perl->new;

	# Parse and process the file to produce the model
	my @model  = ();
	my @errors = $parser->parse_string( delete $self->{text} );
	foreach my $error (@errors) {
		my $line = $error->message . " at " . $error->file . " line " . $error->line;

		#$line = encode('utf8', $line);
		if ( $error->near ) {
			my $near = $error->near;

			# some day when we have unicode in wx ...
			#$near =~ s/\n/\x{c2b6}/g;
			$near =~ s/\n/\\n/g;
			$near =~ s/\r//g;
			$line .= ", near \"$near\"";
		} elsif ( $error->at ) {
			my $at = $error->at;
			$line .= ", at $at";
		}

		push @model, [ 0, $line, $error ];

		foreach my $stack ( $error->stack ) {
			my $line = $stack->sub . " called at " . $stack->file . " line " . $stack->line;
			push @model, [ 1, $line, $stack ];
		}
	}

	# Save the model and we're done
	$self->{model} = \@model;
	return 1;
}

# TO DO: Finish porting this to the new Task API style once someone
# demonstrates what, if anything, is actually using the ErrorList GUI
# at the moment.
sub finish2 {
	my $self = shift;

	# my $main = shift;
	# really not sure if this is right, but parameter passed in isa Padre::Wx::App,
	# not Padre::Wx::Main, however a reference to main is held in Padre::Wx::App
	my $main = shift->{main};
	return if !$main;
	my $errorlist = $main ? $main->errorlist : undef;
	my $data      = $self->data;
	my $parser    = $self->parser;
	$errorlist->{parser} = $parser if $errorlist;

	my @errors = defined $data && $data ne '' ? $parser->parse_string($data) : ();

	foreach my $err (@errors) {
		my $message = $err->message . " at " . $err->file . " line " . $err->line;

		#$message = encode('utf8', $message);
		if ( $err->near ) {
			my $near = $err->near;

			# some day when we have unicode in wx ...
			#$near =~ s/\n/\x{c2b6}/g;
			$near =~ s/\n/\\n/g;
			$near =~ s/\r//g;
			$message .= ", near \"$near\"";
		} elsif ( $err->at ) {
			my $at = $err->at;
			$message .= ", at $at";
		}

		my $err_tree_item = $errorlist->AppendItem( $errorlist->root, $message, -1, -1, Wx::TreeItemData->new($err) );

		if ( $err->stack ) {
			foreach my $stack_item ( $err->stack ) {
				my $stack_message = $stack_item->sub . " called at " . $stack_item->file . " line " . $stack_item->line;
				$errorlist->AppendItem( $err_tree_item, $stack_message, -1, -1, Wx::TreeItemData->new($stack_item) );
			}
		}
	}

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

