package Padre::Project::Temp;

# Project-specific private temporary directory.
# This mechanism will allow us to pull off some really neat tricks,
# like executing unsaved files and syntax-checking changed files
# before they are saved.

use 5.008005;
use strict;
use warnings;
use File::Temp ();

our $VERSION = '0.56';

use Class::XSAccessor {
	getters => {
		root => 'root',
	}
};





######################################################################
# Constructor

sub new {
	bless {
		root => File::Temp::tempdir( CLEANUP => 1 ),
		},
		$_[0];
}

1;
