#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 11;
use Padre::Project::Perl       ();
use Padre::Project::Perl::Temp ();





######################################################################
# Simple Cases

SCOPE: {
	my $string = <<'END_PERL';
package Foo;

use strict;

sub dummy { 2 }

1;
END_PERL

	my $null   = new_ok('Padre::Project::Perl::Temp');
	my $simple = new_ok(
		'Padre::Project::Perl::Temp' => [
			files => {
				'lib/Foo.pm' => $string,
			},
		]
	);
	ok( $simple->run,     '->run ok' );
	ok( $simple->temp,    '->{temp} ok' );
	ok( -d $simple->temp, "->{temp} exists at $simple->{temp}" );
	ok( -f File::Spec->catfile(
			$simple->temp, 'lib', 'Foo.pm',
		),
		'Created package Foo ok',
	);
}





######################################################################
# Project-Based Case

SCOPE: {
	my $root    = File::Spec->catdir(qw{ t collection Config-Tiny});
	my $project = new_ok(
		'Padre::Project::Perl' => [
			root => $root,
		]
	);
	my $temp = new_ok(
		'Padre::Project::Perl::Temp' => [
			project => $project,
			files   => {},
		]
	);
	ok( -d $temp->temp,        '->temp exists' );
	ok( !ref $temp->{project}, '->{project} is flattened' );
	ok( -d $temp->{project},   '->{project} directory exists' );
}
