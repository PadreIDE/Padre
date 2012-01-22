package Padre::QuickFix;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

# Constructor.
# No need to override this
sub new {
	bless {}, $_[0];
}

# Returns the quick fix list
sub quick_fix_list {
	my ( $self, $doc, $editor ) = @_;
	warn "quick_fix_list, You need to override this to do something useful with quick fix";
	return ();
}

1;

__END__

=head1 NAME

Padre::QuickFix - Padre Quick Fix Provider API

=head1 DESCRIPTION

=head2 Quick Fix (Shortcut: C<Ctrl+2>)

This opens a dialog that lists different actions that relate to
fixing the code at the cursor. It will call B<event_on_quick_fix> method
passing a L<Padre::Wx::Editor> object on the current Padre document.
Please see the following sample implementation:

	sub quick_fix_list {
		my ($self, $editor) = @_;

		my @items = (
			{
				text     => '123...',
				listener => sub {
					print "123...\n";
				}
			},
			{
				text     => '456...',
				listener => sub {
					print "456...\n";
				}
			},
		);

		return @items;
	}

=cut

The B<Padre::QuickFix> class provides a base class, default implementation
and API documentation for quick fix provision support in L<Padre>.

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
