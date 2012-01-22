package Padre::Plugin::PopularityContest;

# Note to developers: This module collects data and transmit it to the Padre
# dev team over the Internet. Be very careful which data you collect and
# always check that it is listed in the following POD and keep this module
# very very good commented. Each user should be able to verify what it does.

=pod

=head1 NAME

Padre::Plugin::PopularityContest - The Padre Popularity Contest

=head1 DESCRIPTION

The Padre Popularity Contest is a plug-in that collects various information
about your Padre installation as it runs, and reports that information
over the Internet to a central server.

The information collected from the Popularity Contest plug-in is used by the
development team to track the adoption rate of different features, to help
set the default configuration values, and to prioritise development focus.

In other words, to make life better for you in the next release, and the
ones after that.

=head2 What information will we collect?

At the moment, the following information is collected:

=over

=item Run time of Padre (Time between start and exit of Padre)

=item Type of operating system (platform only: Windows, Linux, Mac, etc.)

=item Padre version number

=item Perl, Wx and wxWidgets version numbers

=item Number of times each menu option is used (directly or via shortcut
or toolbar)

=item MIME type of files (like C<text/plain> or C<application/perl>) which are
opened in Padre

=back

In addition, a random process ID for Padre is created and transmitted just
to identify multiple reports from a single running instance of Padre. It
doesn't match or contain your OS process ID but it allows us to count
duplicate reports from a single running copy only once.
A new ID is generated each time you start Padre and it doesn't allow any
identification of you or your computer.

The following information may be added sooner or later:

=over

=item Enabled/disabled features (like: are tool tips enabled or not?)

=item Selected Padre language

=back

=head2 I feel observed.

Disable this module and no information would be transmitted at all.

All information is anonymous and can't be tracked to you, but it helps
the developer team to know which functions and features are used and
which aren't.

This is an open source project and you're invited to check what this
module does by just opening F<Padre/Plugin/PopularityContest.pm> and check
that it does.

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
this plug-in entirely.

=cut

use 5.008;
use strict;
use warnings;
use Config          ();
use Scalar::Util    ();
use Padre::Plugin   ();
use Padre::Constant ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Plugin';

# Track the number of times actions are used
our %ACTION = ();





######################################################################
# Padre::Plugin Methods

sub padre_interfaces {
	return (
		'Padre::Plugin'           => '0.91',
		'Padre::Task'             => '0.91',
		'Padre::Task::LWP'        => '0.91',
		'Padre::Util::SVN'        => '0.91',
		'Padre::Wx::Dialog::Text' => '0.91',
	);
}

sub plugin_name {
	'Padre Popularity Contest';
}

# Core plugins may reuse the page icon
sub plugin_icon {
	require Padre::Wx::Icon;
	Padre::Wx::Icon::find('logo');
}

sub plugin_enable {
	my $self = shift;
	$self->SUPER::plugin_enable;

	# Load the config
	$self->{config} = $self->config_read;

	# Enable data collection everywhere in Padre
	$self->ide->{_popularity_contest} = $self;

	# Enable counting on all events:
	my $actions = $self->ide->actions;
	foreach ( keys %$actions ) {
		my $action = $actions->{$_};
		my $name   = $action->name;

		# Don't add my event twice in case someone diables/enables me:
		next if exists $ACTION{$name};

		$ACTION{$name} = 0;
		$action->add_event( sub { $ACTION{$name}++ } );
	}

	return 1;
}

# Called when the plugin is disabled by the user or due to an exit-call for Padre
sub plugin_disable {
	my $self = shift;

	# End data collection
	delete $self->ide->{_popularity_contest};

	# Send a report using the data we collected so far
	$self->report;

	# Save the config (if set)
	if ( $self->{config} ) {
		$self->config_write( delete $self->{config} );
	}

	# Make sure our task class is unloaded
	$self->unload('Padre::Plugin::PopularityContext::Ping');

	return 1;
}

sub menu_plugins_simple {

	# TO DO: Add menu options to force sending of a report and to show
	#       the contents of a report.

	return shift->plugin_name => [
		Wx::gettext("About")               => '_about',
		Wx::gettext("Show current report") => 'report_show',
	];
}

# Add one to the usage statistic of an item
sub count { # Item to count
	my $self = shift;
	my $item = shift;

	$self->{stats} = {} if ( !defined( $self->{stats} ) ) or ( ref( $self->{stats} ) ne 'HASH' );

	# We want to keep our namespace limited to a reduced amount of chars:
	$item =~ s/[^\w\.\-\+]+/\_/g;

	++$self->{stats}->{$item};

	return 1;
}

# Compile the report hash
sub _generate {
	my $self   = shift;
	my %report = ();

	# The instance ID id generated randomly on Padre's start-up, it is used
	# to identify multiple reports from one running instance of Padre and
	# to throw away old data once a fresh report with newer data arrives from
	# the same instance ID. Otherwise we would double-count the data from
	# the first report (once at the first and once at the second report which
	# also includs it).
	$report{'padre.instance'} = $self->ide->{instance_id};

	# Versioning information
	require Padre::Util::SVN;
	my $revision = Padre::Util::SVN::padre_revision();
	if ( defined $revision ) {

		# This is a developer build
		$report{'DEV'}            = 1;
		$report{'padre.version'}  = $Padre::VERSION;
		$report{'padre.revision'} = $revision;
	} else {

		# This is a regular build
		$report{'padre.version'} = $Padre::VERSION;
	}

	# The OS is transmitted as Win32, Linux or MAC (or other common names)
	$report{'perl.osname'}   = $^O;
	$report{'perl.archname'} = $Config::Config{archname};

	# The time this Padre has been running until now
	$report{'padre.uptime'} = time - $^T;

	# Perl and WxWidgets version numbers. They help to know which minimal
	# version could be required
	$report{'perl.version'}      = scalar($^V) . '';
	$report{'perl.wxversion'}    = $Wx::VERSION;
	$report{'wx.version_string'} = Wx::wxVERSION_STRING();

	# Add all the action tracking data
	foreach ( grep { $ACTION{$_} } sort keys %ACTION ) {
		$report{"action.$_"} = $ACTION{$_};
	}

	# Add the stats data
	if ( defined( $self->{stats} ) and ( ref( $self->{stats} ) eq 'HASH' ) ) {
		foreach ( keys( %{ $self->{stats} } ) ) {
			$report{$_} = $self->{stats}->{$_};
		}
	}

	return \%report;
}

# Report data to server
sub report {
	my $self   = shift;
	my $report = $self->_generate;

	# TO DO: Enable as soon as the server is functional:
	#	$self->task_request(
	#		task   => 'Padre::Task::LWP'->new(
	#		method => 'POST',
	#		url    => 'http://padre.perlide.org/popularity_contest.cgi',
	#		query  => \%STATS,
	#	);

	return 1;
}

sub report_show {
	my $self   = shift;
	my $report = $self->_generate;

	# Display the report as YAML for mid-level readability
	require YAML::Tiny;
	my $yaml = YAML::Tiny::Dump($report);

	# Show the result in a text box
	require Padre::Wx::Dialog::Text;
	Padre::Wx::Dialog::Text->show(
		$self->main,
		Wx::gettext('Popularity Contest Report'),
		$yaml,
	);
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

1;

=pod

=head1 SUPPORT

See the support section of the main L<Padre> module.

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
