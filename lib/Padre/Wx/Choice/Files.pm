package Padre::Wx::Choice::Files;

# Dropdown box for searchable file types

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::Role::Main ();
use Padre::Locale::T;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Choice
};

use constant OPTIONS => (
	[ _T('All Files'), ''                    ],
	[ _T('Text Files'), 'text/plain'         ],
	[ _T('Perl Files'), 'application/x-perl' ],
);

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Fill the type data
	$self->Clear;
	foreach my $type ( OPTIONS ) {
		$self->Append( Wx::gettext( $type->[0] ), $type->[1] );
	}
	$self->SetSelection(0);

	return $self;
}


1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
