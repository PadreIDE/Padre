package Padre::HelpProvider;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.49';

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

The B<Padre::HelpProvider> class provides a base class, default implementation
and API documentation for help provision support in L<Padre>.

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
