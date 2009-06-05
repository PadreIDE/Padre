#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan( skip_all => 'Needs DISPLAY' );
		exit(0);
	}
}
use File::Find::Rule;
use PPI::Document;

# Calculate the plan
my %modules = map {
	my $class = $_;
	$class =~ s/\//::/g;
	$class =~ s/\.pm$//;
	$class => "lib/$_"
} File::Find::Rule->relative->name('*.pm')->file->in('lib');
plan( tests => scalar(keys %modules) * 5 );

# Compile all of Padre
eval "use Class::Autouse ':devel';";
use File::Temp;
use POSIX qw(locale_h);
$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );
foreach my $module ( sort keys %modules ) {
	require_ok( $module );
	ok( $module->VERSION, "Got $module \$VERSION" );
}

foreach my $module ( sort keys %modules ) {
	# Load the document
	my $document = PPI::Document->new( $modules{$module},
		readonly => 1,
	);
	ok( $document, "PPI can parse $module" );
	unless ( $document ) {
		diag( PPI::Document->errstr );
	}

	# If a method has a current method, never use Padre::Current directly
	SKIP: {
		unless ( $module->can('current') and $module ne 'Padre::Current' ) {
			skip("No ->current method", 1);
		}
		my $good = ! $document->find_any( sub {
			$_[1]->isa('PPI::Token::Word')      or return '';
			$_[1]->content eq 'Padre::Current'  or return '';
			my $arrow = $_[1]->snext_sibling    or return '';
			$arrow->isa('PPI::Token::Operator') or return '';
			$arrow->content eq '->'             or return '';
			my $method = $arrow->snext_sibling  or return '';
			$method->isa('PPI::Token::Word')    or return '';
			$method->content ne 'new'           or return '';
			return 1;
		} );
		ok( $good, "Do not use Padre::Current directly when ->current is possible" );
	}

	# If a method has an ide or main method, never use Padre->ide directly
	SKIP: {
		unless ( $module->can('ide') or $module->can('main') ) {
			skip("No ->ide or ->main method", 1);
		}
		my $good = ! $document->find_any( sub {
			$_[1]->isa('PPI::Token::Word')      or return '';
			$_[1]->content eq 'Padre'           or return '';
			my $arrow = $_[1]->snext_sibling    or return '';
			$arrow->isa('PPI::Token::Operator') or return '';
			$arrow->content eq '->'             or return '';
			my $method = $arrow->snext_sibling  or return '';
			$method->isa('PPI::Token::Word')    or return '';
			$method->content eq 'ide'           or return '';
			return 1;
		} );
		ok( $good, "Do not use Padre->ide when ->ide or ->main is possible" );
	}
}

1;
