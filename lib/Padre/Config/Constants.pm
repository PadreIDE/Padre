#
# Constants used by various configuration systems.
#

package Padre::Config::Constants;

use File::Spec;
use File::Spec::Functions qw{ catdir rel2abs };

# export stuff
use base qw{ Exporter };
our @EXPORT_OK = qw{
	dirs
	$PADRE_HOME
};
our %EXPORT_TAGS = (
	dirs => [ qw{ $PADRE_HOME } ],
);


# list of constants
our $PADRE_HOME = _find_padre_home();



# -- private subs

sub _find_padre_home {
	my $home;
	
	# PADRE_HOME env var set, always use unix style.
	if ( defined $ENV{PADRE_HOME} ) {
		$home = catdir( $ENV{PADRE_HOME}, '.padre' );
		return rel2abs($home);
	}

	# using data dir as defined by the os.
	my $datadir = File::HomeDir->my_data;
	my @subdirs = File::Spec->isa('File::Spec::Win32')
		? qw{ Perl Padre }	# on windows use the traditional vendor/product format
		: qw{ .padre };		# TODO - is mac correctly covered?

	$home = catdir( $datadir, @subdirs );
	return rel2abs($home);
}


1;

__END__

=head1 NAME

Padre::Config::Constants - constants used by config subsystems


=head1 DESCRIPTION

Padre uses various configuration subsystems (see C<Padre::Config> for more
information). Those systems needs to somehow agree on some basic stuff, which
is defined in this module.



=head1 PUBLIC API

=head2 Available constants

This module exports nothing by default. However, some constants can
be imported with:

	use Padre::Config::Constants qw{ $FOO $BAR };


The list of available constants are:

=over 4

=item * $PADRE_HOME

Private Padre configuration directory Padre, used to store stuff.

=back



=head2 Available group of constants

Since lots of constants are somehow related, this module defines some tags
to import them all at once, with eg:

	use Padre::Config::Constants qw{ :dirs };

The tags available are:

=over 4

=item * dirs

Exports C<$PADRE_HOME>.


=back




=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
