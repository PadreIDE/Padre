package Padre::Plugin::Test::Plugin;

use warnings;
use strict;

our $VERSION = '0.01';

my @menu = (
    ['Test Me Too', \&test_me_too],
);

sub menu {
    my ($self) = @_;
    return @menu;
}

sub test_me_too {
	my ( $self, $event ) = @_;
	
	# XXX do something we can test?
}

1;
