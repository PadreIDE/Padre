#!/usr/bin/perl

use warnings;
use strict;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 16 );
}

use File::Spec::Functions ':ALL';
use Test::NoWarnings;
use t::lib::Padre;
use Padre;

my $padre_null = rel2abs( catdir( 't', 'collection', 'Padre-Null' ) );
ok( -d $padre_null, 'Found Padre-Null project' );

my $manager = Padre->new->project_manager;
isa_ok( $manager, 'Padre::ProjectManager' );





#####################################################################
# Load a simple Padre project

SCOPE: {
	my $simple = $manager->project($padre_null);
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
	is( scalar( keys %{ $config->project } ), 2, 'Project config is empty' );
	ok( defined $config->project->fullname, '->fullname is defined' );
	ok( -f $config->project->fullname,      '->fullname exists' );
	ok( defined $config->project->dirname,  '->dirname is defined' );
	ok( -d $config->project->dirname,       '->dirname exists' );
}
