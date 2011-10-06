#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 40 );
}
use Test::NoWarnings;
use File::Spec::Functions ':ALL';

# Padre can move the cwd around, so save in the location of the
# test files early before that happens
my $files = rel2abs( catdir( 't', 'files' ) );

use t::lib::Padre;
use t::lib::Padre::Editor;

use Padre;
use Padre::Document;
use Padre::PPI;
use PPI::Document;

# Create the object so that ide works
my $app = Padre->new;
isa_ok( $app, 'Padre' );

SCOPE: {
	my $editor = t::lib::Padre::Editor->new;
	my $file   = catfile( $files, 'missing_brace_1.pl' );
	my $doc    = Padre::Document->new(
		filename => $file,
	);
	$doc->set_editor($editor);
	$editor->set_document($doc);

	sub is_row_ok {
		my %arg = @_;
		my $row = $arg{row};
		like( $row->{message}, $arg{message}, "message regex match in '$arg{test_name}'" );
		is( $row->{line}, $arg{line}, "line match in '$arg{test_name}'" );
		is( $row->{type}, $arg{type}, "type match in '$arg{test_name}'" );
	}

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
		my $rv = <$fh>;
		close $fh;
		$rv;
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
	my $text = do {
		local $/ = undef;
		open my $fh, '<', $infile or die $!;
		my $rv = <$fh>;
		close $fh;
		$rv;
	};

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

# Regression test for functions
SCOPE: {
	my $editor = t::lib::Padre::Editor->new;
	my $file   = catfile( $files, 'perl_functions.pl' );
	my $doc    = Padre::Document->new(
		filename => $file,
	);
	$doc->set_editor($editor);
	$editor->set_document($doc);

	my @functions = $doc->functions;
	is_deeply(
		\@functions,
		[   qw{
				guess_indentation_style
				guess_filename
				get_calltip_keywords
				two_lines
				three_lines
				after_data
				}
		],
		'Found expected Perl functions',
	);
}

# Regression test for functions on Method::Signatures-style method declarators
SCOPE: {
	my @test_files = (
		{   'filename' => 'method_declarator_1.pm',
			'methods'  => [
				qw/
					_build__ca_state_holidays
					is_holiday_or_weekend
					/
			],
		},
		{   'filename' => 'method_declarator_2.pm',
			'methods'  => [
				qw/
					new
					iso_date
					/
			],
		},
		{   'filename' => 'method_declarator_3.pm',
			'methods'  => [
				qw/
					strip_ws
					/
			],
		},
	);

	foreach my $test_file (@test_files) {
		my $editor = t::lib::Padre::Editor->new;
		my $file   = catfile( $files, $test_file->{'filename'} );
		my $doc    = Padre::Document->new(
			filename => $file,
		);
		$doc->set_editor($editor);
		$editor->set_document($doc);

		my @functions = $doc->functions;
		is_deeply(
			\@functions,
			$test_file->{'methods'},
			'Found expected declarator-declared Perl functions',
		);
	}
}

# Tests for content intuition
SCOPE: {
	my $editor = t::lib::Padre::Editor->new;
	my $doc    = Padre::Document::Perl->new;
	$doc->set_editor($editor);
	$editor->set_document($doc);
	$doc->text_set(<<'END_PERL');
package Foo::Bar::Baz;

1;
END_PERL

	# Check the filename
	my $filename = $doc->guess_filename;
	is( $filename, 'Baz.pm', '->guess_filename ok' );

	# Check the subpath
	my @subpath = $doc->guess_subpath;
	is_deeply( \@subpath, [qw{ lib Foo Bar }], '->guess_subpath' );
}

# Test POD endification
SCOPE: {
	use_ok('Padre::PPI::EndifyPod');
	my $merge = Padre::PPI::EndifyPod->new;
	isa_ok( $merge, 'Padre::PPI::EndifyPod' );
	my $document = PPI::Document->new( \<<'END_PERL' );
package Foo;

=pod

This is POD

=cut

use strict;

=pod

This is also POD

=cut

1;
END_PERL
	isa_ok( $document, 'PPI::Document' );
	ok( $merge->apply($document), 'Transform applied ok' );
	is( $document->serialize, <<'END_PERL', 'Transformed ok' );
package Foo;


use strict;


1;

__END__

=pod

This is POD

This is also POD

=cut
END_PERL
}

# Test copyright updating
SCOPE: {
	use_ok('Padre::PPI::UpdateCopyright');
	my $copyright = Padre::PPI::UpdateCopyright->new(
		name => 'Adam Kennedy',
	);
	isa_ok( $copyright, 'Padre::PPI::UpdateCopyright' );
	my $document = PPI::Document->new( \<<'END_PERL' );
package Foo;

=pod

Copyright 2008 - 2009 Adam Kennedy.

=cut

1;
END_PERL
	isa_ok( $document, 'PPI::Document' );
	ok( $copyright->apply($document), 'Transform applied ok' );
	my $serialized = $document->serialize;
	ok( $serialized =~ /2008 - (\d\d\d\d)/, 'Found copyright statement' );
	ok( $1 ne '2009', 'Copyright year has changed' );
	ok( $1 > 2009, 'Copyright year is newer' );
}





######################################################################
# Support Functions

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
