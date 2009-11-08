package Padre::Task::ErrorParser;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.50';

use base 'Padre::Task';

use Class::XSAccessor getters => {
	parser   => 'parser',
	old_lang => 'old_lang',
	cur_lang => 'cur_lang',
	data     => 'data',
};

require Parse::ErrorString::Perl;

sub run {
	my $self = shift;
	unless ( $self->parser and ( ( !$self->cur_lang and !$self->old_lang ) or ( $self->cur_lang eq $self->old_lang ) ) )
	{

		if ( $self->cur_lang ) {
			$self->{parser} = Parse::ErrorString::Perl->new( lang => $self->cur_lang );
		} else {
			$self->{parser} = Parse::ErrorString::Perl->new;
		}
	}
	return 1;
}

sub finish {
	my $self      = shift;
	my $main      = shift;
	my $errorlist = $main->errorlist;
	my $data      = $self->data;
	my $parser    = $self->parser;
	$errorlist->{parser} = $parser;

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

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

