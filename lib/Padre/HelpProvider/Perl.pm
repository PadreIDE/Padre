package Padre::HelpProvider::Perl;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.43';
our @ISA = 'Padre::HelpProvider';
#
# Initialize help
#
sub help_init {
	warn "help_init, You need to override this to do something useful with help search";
}

#
# Renders the help topic content into XHTML
#
sub help_render {
	warn "helpi_render, You need to override this to do something useful with help search";
}

#
# Returns the help topic list
# 
sub help_list {
	warn "help_list, You need to override this to do something useful with help search";
}

1;

__END__

=head1 NAME

Padre::HelpProvider::Perl - Perl 5 Help Provider

=head1 DESCRIPTION

Perl 5 Help index is built here and rendered.

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
