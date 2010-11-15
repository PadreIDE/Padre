package Padre::Wx::Dialog::Wizard::SelectPage;

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();

our $VERSION = '0.75';
our @ISA     = qw{
	Padre::Wx::Dialog::WizardPage;
};

sub get_name {
	return "Select a Wizard"
}

sub get_title {
	return "Wizard Selector";
}

1;


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::Wizard::SelectPage - the wizard selection page

=head1 DESCRIPTION

This prepares the required page UI that the wizard will include in its UI and has the page
flow information for the next and previous pages.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
