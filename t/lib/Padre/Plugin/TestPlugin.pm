package Padre::Plugin::TestPlugin;

use warnings;
use strict;

our $VERSION = '0.01';

my @menu = (
    ['Test Me', \&test_me],
);

sub menu {
    my ($self) = @_;
    return @menu;
}

sub test_me {
	my ( $self, $event ) = @_;
	
	# XXX do something we can test?
}

1;
