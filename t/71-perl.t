#!/usr/bin/perl

use strict;
use warnings;
use Test::NeedsDisplay;
use Test::More;
use Test::NoWarnings;
use Data::Dumper qw(Dumper);
use File::Spec   ();
use t::lib::Padre;
use t::lib::Padre::Editor;

my $tests;
plan tests => $tests+1;

use Padre::Document;
use Padre::PPI;
use PPI::Document;

my $editor_1 = t::lib::Padre::Editor->new;
my $file_1   = File::Spec->catfile('t', 'files', 'missing_brace_1.pl');
my $doc_1    = Padre::Document->new(
	filename  => $file_1,
);
$doc_1->set_editor($editor_1);
sub Padre::Document::Perl::text_get {
	return q(print "hello);
}
#my $msgs = $doc_1->check_syntax;
#diag Dumper $msgs;
#diag $doc_1->text_get;

SCOPE: {
	isa_ok($doc_1, 'Padre::Document');
	isa_ok($doc_1, 'Padre::Document::Perl');
	is($doc_1->filename, $file_1, 'filename');
	
	#Padre::PPI::find_unmatched_brace();
	BEGIN { $tests += 3; }
}


# tests for Padre::PPI::find_variable_declaration
# and ...find_token_at_location
SCOPE: {
	my $infile = File::Spec->catfile('t', 'files', 'find_variable_declaration_1.pm');
	my $text = do { local $/=undef; open my $fh, '<', $infile or die $!; <$fh> };
  
	my $doc = PPI::Document->new( \$text );
	isa_ok($doc, "PPI::Document");
	$doc->index_locations;
  
	my $elem;
	$doc->find_first(
		sub {
			return 0 if not $_[1]->isa('PPI::Token::Symbol')
			         or not $_[1]->content eq '$n_threads_to_kill'
			         or not $_[1]->location->[0] == 138;
			$elem = $_[1];
			return 1;
		}
	);
	isa_ok( $elem, 'PPI::Token::Symbol' );
  
	$doc->flush_locations(); # TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	#my $doc2 = PPI::Document->new( \$text );
	my $cmp_elem = Padre::PPI::find_token_at_location($doc, [138, 33, 33]);
	ok( $elem == $cmp_elem, 'find_token_at_location returns the same token as a manual search' );
	my $declaration;
	$doc->find_first(
		sub {
			return 0 if not $_[1]->isa('PPI::Statement::Variable')
			         or not $_[1]->location->[0] == 126;
			$declaration = $_[1];
			return 1;
		}
	);
	isa_ok( $declaration, 'PPI::Statement::Variable' );
  
	$doc->flush_locations(); # TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	my $cmp_declaration = Padre::PPI::find_token_at_location($doc, [126, 2, 9]);
	# They're not really the same. The manual search finds the entire Statement node. Hence the first_element.
	ok( $declaration->first_element() == $cmp_declaration, 'find_token_at_location returns the same token as a manual search' );

	my $result_declaration = Padre::PPI::find_variable_declaration($elem);

	ok( $declaration == $result_declaration, 'Correct declaration found');

	BEGIN { $tests += 6; }
}


