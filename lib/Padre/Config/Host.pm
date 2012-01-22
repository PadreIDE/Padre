package Padre::Config::Host;

# Configuration and state data related to the host that Padre is running on.

use 5.008;
use strict;
use warnings;
use Scalar::Util ();

our $VERSION = '0.94';

# -- constructors

#
# my $config = Padre::Config::Host->_new( $href );
#
# create & return a new config object. if $href is not supplied, the config
# object will be empty. this constructor is private and should not be used
# outside this class.
#
sub _new {
	my ( $class, $href ) = @_;
	$href ||= {};
	bless $href, $class;
	return $href;
}

#
# my $config = Padre::Config::Host->read;
#
sub read {
	my $class = shift;

	# Read in the config data
	require Padre::DB;
	my %hash = map { $_->name => $_->value } Padre::DB::HostConfig->select;

	# Create and return the object
	return $class->_new( \%hash );
}

# -- public methods

#
# my $new = $config->clone;
#
sub clone {
	my $self  = shift;
	my $class = Scalar::Util::blessed($self);
	return bless {%$self}, $class;
}

#
# $config->write;
#
sub write {
	my $self = shift;
	require Padre::DB;

	# This code can run before we have a ::Main object.
	# As a result, it uses slightly bizarre locking code to make sure it runs
	# inside a transaction correctly in both cases (has a ::Main, or not)
	my $main = eval {

		# If ::Main isn't even loaded, we don't need the more
		# intensive Padre::Current call. It also prevents loading
		# the Wx subsystem when we are running light and headless
		# with no GUI at all.
		if ($Padre::Wx::Main::VERSION) {
			local $@;
			require Padre::Current;
			Padre::Current->main;
		}
	};
	my $lock = $main ? $main->lock('DB') : undef;
	Padre::DB->begin unless $lock;
	Padre::DB::HostConfig->truncate;
	foreach my $name ( sort keys %$self ) {
		Padre::DB::HostConfig->create(
			name  => $name,
			value => $self->{$name},
		);
	}
	Padre::DB->commit unless $lock;

	return 1;
}

1;

__END__

=pod

=head1 NAME

Padre::Config::Host - Padre configuration storing host state data

=head1 DESCRIPTION

This class implements the state data of the host on which Padre is running.
See L<Padre::Config> for more information on the various types of preferences
supported by Padre.

All those state data are stored in a database managed with C<Padre::DB>.
Refer to this module for more information on how this works.

=head1 PUBLIC API

=head2 Constructors

=over 4

=item read

    my $config = Padre::Config::Host->read;

Load & return the host configuration from the database. Return C<undef> in
case of failure.

No parameters.

=back

=head2 Object methods

=over 4

=item write

    $config->write;

(Over-)write host configuration to the database.

No parameters.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
