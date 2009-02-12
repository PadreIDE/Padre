package Padre::Document::Shell;

######################################################
### This Class will be moved to a plugin (CLAUDIO) ###
######################################################

use 5.008;
use strict;
use warnings;

our $VERSION = '0.27';
our @ISA     = 'Padre::Document';

sub get_command {
        my $self     = shift;

        # Check the file name
        my $filename = $self->filename;

        my $dir = File::Basename::dirname($filename);
        chdir $dir;
        return Padre->ide->config->run_stacktrace
                ? qq{"sh" "-xv" "$filename"}
                : qq{"sh" "$filename"};
}

sub errstr {
        # Empty placeholder
        }


1;
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
