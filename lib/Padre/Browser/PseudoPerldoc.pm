package Padre::Browser::PseudoPerldoc;

use 5.008;
use strict;
use warnings;
use Pod::Perldoc        ();
use Pod::Perldoc::ToPod ();

our $VERSION = '0.94';
our @ISA     = 'Pod::Perldoc';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	return $self;
}

## Lie to Pod::PerlDoc - and avoid it's autoloading implementation
sub find_good_formatter_class {
	$_[0]->{'formatter_class'} = 'Pod::Perldoc::ToPod';
	return;
}

# Even worse than monkey patching , copy paste from Pod::Perldoc w/ edits
# to avoid untrappable calls to 'exit'
sub process {

	# if this ever returns, its retval will be used for exit(RETVAL)

	my $self = shift;

	# TO DO: make it deal with being invoked as various different things
	#  such as perlfaq".

	# (Ticket #672)

	return $self->usage_brief unless @{ $self->{'args'} };
	$self->pagers_guessing;
	$self->options_reading;
	$self->aside( sprintf "$0 => %s v%s\n", ref($self), $self->VERSION );
	$self->drop_privs_maybe;
	$self->options_processing;

	# Hm, we have @pages and @found, but we only really act on one
	# file per call, with the exception of the opt_q hack, and with
	# -l things

	$self->aside("\n");

	my @pages;
	$self->{'pages'} = \@pages;
	if    ( $self->opt_f ) { @pages = ("perlfunc") }
	elsif ( $self->opt_q ) { @pages = ( "perlfaq1" .. "perlfaq9" ) }
	elsif ( $self->opt_v ) { @pages = ("perlvar") }
	else                   { @pages = @{ $self->{'args'} }; }

	return $self->usage_brief unless @pages;

	$self->find_good_formatter_class;
	$self->formatter_sanity_check;

	$self->maybe_diddle_INC;

	# for when we're apparently in a module or extension directory

	my @found = $self->grand_search_init( \@pages );
	return unless @found;

	if ( $self->opt_l ) {
		print join( "\n", @found ), "\n";
		return;
	}

	$self->tweak_found_pathnames( \@found );
	$self->assert_closing_stdout;
	return $self->page_module_file(@found) if $self->opt_m;

	return $self->render_and_page( \@found );
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
