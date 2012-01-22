package Padre::Wx::Role::View;

use 5.008005;
use strict;
use warnings;

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';

1;

__END__

=pod

=head1 NAME

Padre::Wx::Role::View - A role for GUI tools that live in panels

=head1 SYNOPSIS

    # From the Padre::Wx::Role::View section of Padre::Wx::FunctionList
    
    sub view_panel {
        return 'right';
    }
    
    sub view_label {
        Wx::gettext('Functions');
    }
    
    sub view_close {
        shift->{main}->show_functions(0);
    }

=head1 DESCRIPTION

This is a role that should be inherited from by GUI components that
live in the left, right or bottom notebook panels of Padre.

Anything that inherits from this role is expected to implement a number
of methods that allow it to play nicely with the Padre object model.

=head1 METHODS

To help compartmentalise methods that are provided by different roles,
a "view_" prefix is used across methods expected by the role.

=head2 view_panel

This method describes which panel the tool lives in.

Returns the string 'right', 'left', or 'bottom'.

=head2 view_label

The method returns the string that the notebook label should be filled
with. This should be internationalised properly. This method is called
once when the object is constructed, and again if the user triggers a
C<relocale> cascade to change their interface language.

=head2 view_close

This method is called on the object by the event handler for the "X"
control on the notebook label, if it has one.

The method should generally initiate whatever is needed to close the
tool via the highest level API. Note that while we aren't calling the
equivalent menu handler directly, we are calling the high-level method
on the main window that the menu itself calls.

=head1 OPTIONAL

=head2 view_icon

This method should return a valid Wx bitmap to be used as the icon for
a notebook page (displayed alongside C<view_label>).

=head2 view_start

Called immediately after the view has been displayed, to allow the view
to kick off any timers or do additional post-creation setup.

=head2 view_stop

Called immediately before the view is hidden, to allow the view to cancel
any timers, cancel tasks or do pre-destruction teardown.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
