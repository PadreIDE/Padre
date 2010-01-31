package Padre::Project::Perl::DZ;

# Perl project driven by Dist::Zilla

use 5.008005;
use strict;
use warnings;
use Padre::Project::Perl ();

our $VERSION = '0.55';
our @ISA     = 'Padre::Project::Perl';

use Class::XSAccessor {
	getters => {
		dist_ini => 'dist_ini',
	}
};

1;
