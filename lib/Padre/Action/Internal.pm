package Padre::Action::Internal;

# Actions for internal usage within Padre
# Usually not used within menus or toolbar.

=pod

=head1 NAME

Padre::Action::Internal creates Actions for internal usage, for example:
	- testing
	- debugging

=cut

use 5.008;
use strict;
use warnings;

use Data::Dumper ();
use File::Spec();

use Padre::Action ();
use Padre::Current qw{_CURRENT};
use Padre::Constant();

our $VERSION = '0.51';

#####################################################################

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Script Execution
	Padre::Action->new(
		name       => 'internal.dump_padre',
		label      => Wx::gettext('Dump the Padre object to STDOUT'),
		comment    => Wx::gettext('Dumps the complete Padre object to STDOUT for testing/debugging.'),
		menu_event => sub {
			open my $dumpfh, '>', File::Spec->catfile( Padre::Constant::PADRE_HOME, 'padre.dump' );
			print $dumpfh "# Begin Padre dump\n" . Data::Dumper::Dumper( Padre->ide ) . "# End Padre dump\n" . "1;\n";
			close $dumpfh;
		},
	);

	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
