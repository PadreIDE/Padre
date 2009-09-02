package Padre::Plugin::PopularityContest;

=pod

=head1 NAME

Padre::Plugin::PopularityContest - The Padre Popularity Contest

=head1 DESCRIPTION

The Padre Popularity Contest is a plugin that collects various information
about your Padre installation as it runs, and reports that information
over the internet to a central server.

The information collected from the Popularity Contest Plugin is used by the
development team to track the adoption rate of different features, to help
set the default configuration values, and to prioritise development focus.

In otherwords, to make life better for you in the next release, and the
ones after that.

=head2 What information will we collect?

Right now? Nothing. It does nothing, and it collects nothing whatsoever.

It is merely a stub to store your permission to allow us to collect 
information later.

We're not B<exactly> sure what we'll need yet, and the plan is to
gradually add hooks one at a time as needed.

=head2 What information WON'T we collect?

There are some things we can be B<very> clear about.

1. We will B<NEVER> begin to collect information of any kind without
you first explicitly telling us we are allowed to collect that type
of information.

2. We will B<NEVER> copy any information that would result in
a violation of your legal rights, including copyright.
That means we won't collect, record, or transmit the contents of any file.

3. We will B<NEVER> transmit the name of any file, or the cryptographic
hash of any file, or any other unique identifier of any file, although we
may need to record them locally as index keys or for optimisation purposes.

3. We will B<NEVER> transmit any information that relates to you
personally unless you have given it to us already (in which case we'll
only send an account identifier, not the details themselves).

4. We will B<NEVER> transmit any information about your operating system,
or any information about your network that could possibly compromise
security in any way.

5. We will take as much care as we can to ensure that the collection,
analysis, compression and/or transmission of your information consumes
as little resources as possible, and we will in particular attempt to
minimize the resource impact while you are actively coding.

Finally, if you really don't trust us (or you aren't allowed to trust us
because you work inside a secure network) then we encourage you to delete
this plugin entirely.

=cut

use 5.008;
use strict;
use warnings;
use Padre::Plugin ();

our $VERSION = '0.45';
our @ISA     = 'Padre::Plugin';





######################################################################
# Padre::Plugin Methods

sub plugin_name {
	'Padre Popularity Contest';
}

sub plugin_interfaces {
	'Padre::Plugin' => 0.43;
}

sub plugin_enable {
	my $self = shift;
	$self->SUPER::plugin_enable;

	# Load the config
	$self->{config} = $self->config_read;

	# Trigger the ping at enable time.
	# Not sure how load'y this will be, but lets try it
	# for now and see how things end up.
	$self->_ping;

	return 1;
}

sub plugin_disable {
	my $self = shift;

	# Save the config (if set)
	if ( $self->{config} ) {
		$self->config_write( delete $self->{config} );
	}

	# Make sure our task class is unloaded
	require Class::Unload;
	Class::Unload->unload('Padre::Plugin::PopularityContext::Ping');

	$self->SUPER::plugin_disable;
}

sub menu_plugins_simple {
	return shift->plugin_name => [
		Wx::gettext("About") => '_about',
		Wx::gettext("Ping")  => '_ping',
	];
}





######################################################################
# Private Methods

sub _about {
	my $self  = shift;
	my $about = Wx::AboutDialogInfo->new;
	$about->SetName(__PACKAGE__);
	$about->SetDescription("Trying to figure out what do people use?\n");
	Wx::AboutBox($about);
	return;
}

sub _ping {
	my $self = shift;

	# Send the request
	require Padre::Plugin::PopularityContest::Ping;
	Padre::Plugin::PopularityContest::Ping->new->schedule;

	return;
}

1;

=pod

=head1 SUPPORT

See the support section of the main L<Padre> module.

=head1 COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
