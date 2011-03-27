#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

plan tests => 6;

use Test::NoWarnings;
use t::lib::Padre;

# Testing the non-Padre code of
# Padre::Document::Perl::Autocomplete
# that will be moved to some external package

use Padre::Document::Perl::Autocomplete;

{
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
}

my $text_with_variables = <<'END_TEXT';
$file
$ficus
my $force;
@foo
%foobar
%fido
@fungus
END_TEXT

{
	my $parser;
	my $ac = Padre::Document::Perl::Autocomplete->new(
		prefix    => '$f',
		pre_text  => $text_with_variables,
		post_text => '',

		nextchar                     => '',
		minimum_prefix_length        => 1,
		maximum_number_of_choices    => 20,
		minimum_length_of_suggestion => 3,
	);
	my @result = $ac->run($parser);
	is_deeply \@result, [], 'scalar';


	@result = $ac->auto;
	is_deeply \@result,
		[
		1,
		'fungus',
		'fido',
		'foobar',
		'foo',
		'force',
		'ficus',
		'file'
		],
		'auto scalar';

	#diag explain \@result;
}

{
	my $parser;
	my $ac = Padre::Document::Perl::Autocomplete->new(
		prefix    => '$',
		pre_text  => $text_with_variables,
		post_text => '',

		nextchar                     => '',
		minimum_prefix_length        => 1,
		maximum_number_of_choices    => 20,
		minimum_length_of_suggestion => 3,
	);
	my @result = $ac->run($parser);
	is_deeply \@result, [], 'scalar';


	@result = $ac->auto;

	#diag explain \@result;
	is_deeply \@result,
		[
		1,
		],
		'auto scalar';
}





sub read_file {
	my $file = shift;
	open my $fh, '<', $file or die;
	local $/ = undef;
	my $cont = <$fh>;
	close $fh;
	return $cont;
}

