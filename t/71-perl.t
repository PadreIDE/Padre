#!/usr/bin/perl

use strict;
use warnings;
#use Test::NeedsDisplay;
use Test::More;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

use Test::NoWarnings;
use File::Spec::Functions ':ALL';

# Padre can move the cwd around, so lock in the location of the
# test files early before that happens
my $files = rel2abs( catdir( 't', 'files' ) );

my $tests;
plan tests => $tests+1;

use t::lib::Padre;
use t::lib::Padre::Editor;

use Padre::Document;
use Padre::PPI;
use PPI::Document;





SCOPE: {
	my $editor = t::lib::Padre::Editor->new;
	my $file   = catfile( $files, 'missing_brace_1.pl' );
	my $doc    = Padre::Document->new(
		filename  => $file,
	);
	$doc->set_editor($editor);
	$editor->configure_editor($doc);

	my $msgs = $doc->check_syntax;
	is_deeply ($msgs, [
           {
             'msg' => 'Missing right curly or square bracket, at end of line',
             'severity' => 'E',
             'line' => '10'
           },
           {
             'msg' => 'syntax error, at EOF',
             'severity' => 'E',
             'line' => '10'
           }
	]);

	isa_ok($doc, 'Padre::Document');
	isa_ok($doc, 'Padre::Document::Perl');
	is($doc->filename, $file, 'filename');
	
	#Padre::PPI::find_unmatched_brace();
	BEGIN { $tests += 4; }
}





# tests for Padre::PPI::find_variable_declaration
# and ...find_token_at_location
SCOPE: {
	my $infile = catfile( $files, 'find_variable_declaration_1.pm' );
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





# Test for check_syntax
SCOPE: {
	my $editor = t::lib::Padre::Editor->new;
	my $file   = catfile( $files, 'one_char.pl' );
	my $doc    = Padre::Document->new(
		filename  => $file,
	);
	$doc->set_editor($editor);
	$editor->configure_editor($doc);

	my $msgs = $doc->check_syntax;
	my $end  = $msgs->[-1];
	is_deeply(
		$end,
		{
			'msg'      => 'Useless use of a constant in void context',
			'severity' => 'W',
			'line'     => '1',
		}
	);
	BEGIN { $tests += 1; }
}
