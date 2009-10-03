#!/usr/bin/perl

use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 12 );
}

use File::Spec::Functions ':ALL';
use Test::NoWarnings;
use t::lib::Padre;
use Padre;

my $padre_null = rel2abs( catdir( 't', 'collection', 'Padre-Null' ) );
ok( -d $padre_null, 'Found Padre-Null project' );

my $ide = Padre->new;
isa_ok( $ide, 'Padre' );





#####################################################################
# Load a simple Padre project

SCOPE: {
	my $simple = $ide->project($padre_null);
	isa_ok( $simple, 'Padre::Project' );
	is( ref($simple),  'Padre::Project', 'Creates an actual Padre project' );
	is( $simple->root, $padre_null,      '->root ok' );
	ok( -f $simple->padre_yml, '->padre_yml exists' );

	# The project should have an empty config
	my $config = $simple->config;
	isa_ok( $config,          'Padre::Config' );
	isa_ok( $config->host,    'Padre::Config::Host' );
	isa_ok( $config->human,   'Padre::Config::Human' );
	isa_ok( $config->project, 'Padre::Config::Project' );
	is( scalar( keys %{ $config->project } ), 0, 'Project config is empty' );
}
