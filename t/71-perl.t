#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 24 );
}
use Test::NoWarnings;
use File::Spec::Functions ':ALL';

# Padre can move the cwd around, so save in the location of the
# test files early before that happens
my $files = rel2abs( catdir( 't', 'files' ) );

use t::lib::Padre;
use t::lib::Padre::Editor;

use Padre::Document;
use Padre::PPI;
use PPI::Document;

# Create the object so that Padre->ide works
my $app = Padre->new;
isa_ok( $app, 'Padre' );

SCOPE: {
	my $editor = t::lib::Padre::Editor->new;
	my $file   = catfile( $files, 'missing_brace_1.pl' );
	my $doc    = Padre::Document->new(
		filename => $file,
	);
	$doc->set_editor($editor);
	$editor->configure_editor($doc);

	my $msgs = $doc->check_syntax;
	is_deeply(
		$msgs,
		[   {   'msg'      => 'Missing right curly or square bracket, at end of line',
				'severity' => 'E',
				'line'     => '17'
			},
			{   'msg'      => 'syntax error, at EOF',
				'severity' => 'E',
				'line'     => '17'
			}
		]
	);

	isa_ok( $doc, 'Padre::Document' );
	isa_ok( $doc, 'Padre::Document::Perl' );
	is( $doc->filename, $file, 'filename' );
}

# first block of tests for Padre::PPI::find_variable_declaration
# and ...find_token_at_location
SCOPE: {
	my $infile = catfile( $files, 'find_variable_declaration_1.pm' );
	my $text = do {
		local $/ = undef;
		open my $fh, '<', $infile or die $!;
		<$fh>;
	};
	my $doc = PPI::Document->new( \$text );
	isa_ok( $doc, "PPI::Document" );
	$doc->index_locations;

	my $elem = find_var_simple( $doc, '$n_threads_to_kill', 137 );
	isa_ok( $elem, 'PPI::Token::Symbol' );

	$doc->flush_locations(); # TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	                         #my $doc2 = PPI::Document->new( \$text );
	my $cmp_elem = Padre::PPI::find_token_at_location( $doc, [ 137, 26, 26 ] );
	ok( $elem == $cmp_elem, 'find_token_at_location returns the same token as a manual search' );
	my $declaration;
	$doc->find_first(
		sub {
			return 0
				if not $_[1]->isa('PPI::Statement::Variable')
					or not $_[1]->location->[0] == 131;
			$declaration = $_[1];
			return 1;
		}
	);
	isa_ok( $declaration, 'PPI::Statement::Variable' );

	$doc->flush_locations(); # TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	my $cmp_declaration = Padre::PPI::find_token_at_location( $doc, [ 131, 2, 9 ] );

	# They're not really the same. The manual search finds the entire Statement node. Hence the first_element.
	ok( $declaration->first_element() == $cmp_declaration,
		'find_token_at_location returns the same token as a manual search'
	);

	my $result_declaration = Padre::PPI::find_variable_declaration($elem);

	ok( $declaration == $result_declaration, 'Correct declaration found' );
}

# second block of tests for Padre::PPI::find_variable_declaration
# and ...find_token_at_location
SCOPE: {
	my $infile = catfile( $files, 'find_variable_declaration_2.pm' );
	my $text = do { local $/ = undef; open my $fh, '<', $infile or die $!; <$fh> };

	my $doc = PPI::Document->new( \$text );
	isa_ok( $doc, "PPI::Document" );
	$doc->index_locations;

	# Test foreach my $i
	my $elem = find_var_simple( $doc, '$i', 8 ); # search $i in line 8
	isa_ok( $elem, 'PPI::Token::Symbol' );

	$doc->flush_locations(); # TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	my $cmp_elem = Padre::PPI::find_token_at_location( $doc, [ 8, 5, 5 ] );
	ok( $elem == $cmp_elem, 'find_token_at_location returns the same token as a manual search' );

	$doc->flush_locations(); # TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	my $declaration = Padre::PPI::find_token_at_location( $doc, [ 7, 14, 14 ] );
	isa_ok( $declaration, 'PPI::Token::Symbol' );
	my $prev_sibling = $declaration->sprevious_sibling();
	ok( (           defined($prev_sibling)
				and $prev_sibling->isa('PPI::Token::Word')
				and $prev_sibling->content() =~ /^(?:my|our)$/
		),
		"Find variable declaration in foreach"
	);

	$doc->flush_locations(); # TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	my $result_declaration = Padre::PPI::find_variable_declaration($elem);
	ok( $declaration == $result_declaration, 'Correct declaration found' );

	# Now the same for "for our $k"
	$elem = find_var_simple( $doc, '$k', 11 ); # search $k in line 11
	isa_ok( $elem, 'PPI::Token::Symbol' );

	# TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	$doc->flush_locations();
	$cmp_elem = Padre::PPI::find_token_at_location( $doc, [ 11, 5, 5 ] );
	ok( $elem == $cmp_elem, 'find_token_at_location returns the same token as a manual search' );

	# TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	$doc->flush_locations();
	$declaration = Padre::PPI::find_token_at_location( $doc, [ 10, 11, 11 ] );
	isa_ok( $declaration, 'PPI::Token::Symbol' );
	$prev_sibling = $declaration->sprevious_sibling();
	ok( (           defined($prev_sibling)
				and $prev_sibling->isa('PPI::Token::Word')
				and $prev_sibling->content() =~ /^(?:my|our)$/
		),
		"Find variable declaration in foreach"
	);

	# TODO: This shouldn't have to be here. But remove it and things break -- Adam?
	$doc->flush_locations();
	SKIP: {
		skip( "PPI parses 'for our \$foo (...){}' badly", 1 );
		$result_declaration = Padre::PPI::find_variable_declaration($elem);
		ok( $declaration == $result_declaration, 'Correct declaration found' );
	}
}

# Test for check_syntax
SCOPE: {
	my $editor = t::lib::Padre::Editor->new;
	my $file   = catfile( $files, 'one_char.pl' );
	my $doc    = Padre::Document->new(
		filename => $file,
	);
	$doc->set_editor($editor);
	$editor->configure_editor($doc);

	my $msgs = $doc->check_syntax;
	my $end  = $msgs->[-1];
	is_deeply(
		$end,
		{   'msg'      => 'Useless use of a constant in void context',
			'severity' => 'W',
			'line'     => '1',
		}
	);
}

sub find_var_simple {
	my $doc     = shift;
	my $varname = shift;
	my $line    = shift;

	my $elem;
	$doc->find_first(
		sub {
			return 0
				if not $_[1]->isa('PPI::Token::Symbol')
					or not $_[1]->content eq $varname
					or not $_[1]->location->[0] == $line;
			$elem = $_[1];
			return 1;
		}
	);
	return $elem;
}
