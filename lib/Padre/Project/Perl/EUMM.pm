package Padre::Project::Perl::EUMM;

# Perl project driven by ExtUtils::MakeMaker

use 5.008005;
use strict;
use warnings;
use Padre::Project::Perl ();

our $VERSION = '0.55';
our @ISA     = 'Padre::Project::Perl';

use Class::XSAccessor {
	getters => {
		makefile_pl => 'makefile_pl',
	}
};

1;
