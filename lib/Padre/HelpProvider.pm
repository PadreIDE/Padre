package Padre::HelpProvider;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.56';

#
# Constructor.
# No need to override this, just override help_init
#
sub new {
	my ($class) = @_;

	# Create myself :)
	my $self = bless {}, $class;

	# initialize help
	$self->help_init;

	return $self;
}

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
	warn "help_render, You need to override this to do something useful with help search";
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

Padre::HelpProvider - Padre Help Provider API

=head1 DESCRIPTION

The C<Padre::HelpProvider> class provides a base class, default implementation
and API documentation for help provision support in L<Padre>.

In order to setup a help system for a document type called XYZ one has to do the following:
Create a module called Padre::HelpProvider::XYZ that subclasses the Padre::HelpProvider module
and override 3 methods: help_init, help_list and help_render.

In the class representing the Document (Padre::Document::XYX) one should override the
get_help_provider method and return an object of the help provide module.
In our case it should contain

	require Padre::HelpProvider::XYZ;
	return Padre::HelpProvider::XYZ->new;

(TODO: Maybe it should only return the name of the module)

The help_init method is called by the new method of Padre::HelpProvider once for every
document of XYZ kind. (TODO: maybe it should be only once for every document type, and not
once for every document of that type).

help_list should return a reference to an array holding the possible strings the system can 
provide help for.

help_render is called by one of the keywords, it should return the HTML to be displayed
as help and another string which is the location of the help. Usually a path to a file
that will be used in the title of the window.


=cut


# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
