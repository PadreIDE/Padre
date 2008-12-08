package Padre::Plugin::JavaScript;

# Light plugin with no menu entries.
# Provides JavaScript document support.

use 5.008;
use strict;
use warnings;
use Class::Autouse 'Padre::Document::JavaScript';

our $VERSION = '0.20';

use base 'Padre::Plugin';





######################################################################
# Padre::Plugin API Methods

sub padre_interfaces {
	'Padre::Plugin'          => 0.18,
	'Padre::Document'        => 0.18,
}

sub registered_documents {
	'application/javascript' => 'Padre::Document::JavaScript',
	'application/json'       => 'Padre::Document::JavaScript',
}

1;
