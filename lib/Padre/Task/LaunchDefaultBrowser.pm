package Padre::Task::LaunchDefaultBrowser;

# The Wx::LaunchDefaultBrowser function blocks until the default
# browser has been launched. For something like a heavily loaded down
# Firefox, this can take perhaps a minute.
# This task moves the function into the background.

use 5.008;
use strict;
use warnings;
use Padre::Task ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';

sub run {

	# We don't need to load all of Padre::Wx for this,
	# but we do need the minimum bits of wxWidgets.
	require Wx;

	Wx::LaunchDefaultBrowser( $_[0]->{url} );
	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
