package Padre::Wx::Dialog::Wizard::Perl::Module;

use 5.008;
use strict;
use warnings;
use Padre::Wx                     ();
use Padre::Wx::TreeCtrl           ();
use Padre::Wx::Dialog::WizardPage ();

our $VERSION = '0.90';
our @ISA     = qw(Padre::Wx::Dialog::WizardPage);

# Initialize the page
sub init {
	my $self = shift;

	$self->name( Wx::gettext('Creates a Perl 5 module or script') );
	$self->title( Wx::gettext('Perl 5 Module Wizard') );

	# Back to select page
	$self->back_wizard(0);
}

# Add controls to page
sub add_controls {
	my $self = shift;

	#my $module_name = Wx::TextCtrl->new('');
	#my $extends_class;
	#my $perl_min_version;
	#my $getopt_support;
	#my $generate_boilerplate;

	# Main vertical sizer
	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);

	$self->SetSizer($sizer);
	$self->Fit;
}

# Add events to page
sub add_events {
	my $self = shift;

}

# Show the page
sub show {
	my $self = shift;

}

1;


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::Wizard::Perl::Module - a Perl 5 Module Wizard

=head1 DESCRIPTION

This prepares the required page UI that the wizard will include in its UI and 
has the page flow information for the next and previous pages.

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
