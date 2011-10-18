#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;
use Padre::Project::Perl ();

# Locate the test project directory
my $root = File::Spec->catdir( 't', 'collection', 'Config-Tiny' );
ok( -d $root, 'Test project exists' );

# Create the project object
my $project = new_ok( 'Padre::Project::Perl' => [ root => $root ] );
