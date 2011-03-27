#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

plan tests => 2;

use Test::NoWarnings;
use t::lib::Padre;

# Testing the non-Padre code of
# Padre::Document::Perl::Autocomplete
# that will be moved to some external package

use Padre::Document::Perl::Autocomplete;

my $prefix = '$self->{';
my $text   = read_file('t/files/Debugger.pm');
my $parser;

my $ac = Padre::Document::Perl::Autocomplete->new(
	prefix    => $prefix,
	pre_text  => $text,
	post_text => '',
);
my @result = $ac->run($parser);
is_deeply \@result, [ 0, 'xyz' ], 'hash-ref';

#diag explain \@result;


sub read_file {
	my $file = shift;
	open my $fh, '<', $file or die;
	local $/ = undef;
	my $cont = <$fh>;
	close $fh;
	return $cont;
}

