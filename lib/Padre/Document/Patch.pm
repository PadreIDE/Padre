package Padre::Document::Patch;

use 5.008;
use strict;
use warnings;
use Padre::Document;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Document
};


sub event_on_context_menu
{
	my ( $self, $editor, $menu, $event ) = @_;
	$menu->{patch_diff} = $menu->add_menu_action(
	    'edit.patch_diff',
	);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
