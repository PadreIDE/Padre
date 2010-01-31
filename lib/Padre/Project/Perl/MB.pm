package Padre::Project::Perl::MB;

# Perl project driven by Module::Build

use 5.008005;
use strict;
use warnings;
use Padre::Project::Perl ();

our $VERSION = '0.55';
our @ISA     = 'Padre::Project::Perl';

use Class::XSAccessor {
	getters => {
		build_pl => 'build_pl',
	}
};

1;
