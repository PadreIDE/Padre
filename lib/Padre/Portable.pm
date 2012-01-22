package Padre::Portable;

# Provides common functionality needed for Portable Perl support

use 5.008;
use strict;
use warnings;
use File::Spec 3.21 (); # 3.21 needed for volume-safe abs2rel
use Params::Util    ();
use Padre::Constant ();

our $VERSION = '0.94';

sub freeze {
	return shift unless defined Params::Util::_STRING( $_[0] );
	File::Spec->abs2rel( shift, Padre::Constant::PORTABLE );
}

sub thaw {
	return shift unless defined Params::Util::_STRING( $_[0] );
	File::Spec->rel2abs( shift, Padre::Constant::PORTABLE );
}

# Special case for situations where the value might be a directory
# and MIGHT be the same as the portable root directory.
sub freeze_directory {
	return shift unless defined Params::Util::_STRING( $_[0] );
	my $rel = File::Spec->abs2rel( shift, Padre::Constant::PORTABLE );
	return length($rel) ? $rel : File::Spec->curdir;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
