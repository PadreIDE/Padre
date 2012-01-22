package Padre::Util::Template;

=pod

=head1 NAME

Padre::Util - Padre utility functions for new-file-templates

=head1 DESCRIPTION

The C<Padre::Util::Template> package contains helper functions for templates
used to create new files. They should be backward-compatible all the time as
they might be used by user-created templates not living on the Padre storage.

We're using Template::Tiny which is unable to pass arguments to method calls,
so we need to have one method per case.

=head1 FUNCTIONS

=cut

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

# This is a Padre::Util module where the subs should be called as functions,
# but Template::Tiny requires us to use a blessed package and we could use
# the object as a cache.
sub new {
	my $class = shift;

	my $self = bless {}, $class;

	return $self;
}


=pod

=head2 C<new_modulename>

Asks for the name of a new module which is returned.

Return the user replied value on subsequent calls.

=cut

sub new_modulename {
	my $self = shift;

	$self->{_modulename} ||= Padre->ide->wx->main->prompt( Wx::gettext('Module name:'), Wx::gettext('New Module') )
		|| 'New::Module';

	return $self->{_modulename};
}

1;

__END__

=pod

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
