package Padre::PluginBuilder;

=pod

=head1 NAME

Padre::PluginBuilder - L<Module::Build> subclass for building Padre plug-ins

=head1 DESCRIPTION

This is a L<Module::Build> subclass that can be used in place of L<Module::Build>
for the C<Build.PL> of Padre plug-ins. It adds two new build targets for
the plug-ins:

=head1 ADDITIONAL BUILD TARGETS

=head2 C<plugin>

Generates a F<.par> file that contains all the plug-in code. The name of the file
will be according to the plug-in class name: C<Padre::Plugin::Foo> will result
in F<Foo.par>.

Installing the plug-in (for the current architecture) will be as simple as copying
the generated F<.par> file into the C<plugins> directory of the user's Padre
configuration directory (which defaults to F<~/.padre> on Unix systems).

=cut

use 5.008;
use strict;
use warnings;
use Module::Build   ();
use Padre::Constant ();

our $VERSION = '0.94';
our @ISA     = 'Module::Build';

sub ACTION_plugin {
	my ($self) = @_;

	# Need PAR::Dist
	# Don't make a dependency in the Padre Makefile.PL for this
	if ( not eval { require PAR::Dist; PAR::Dist->VERSION(0.17) } ) {
		$self->log_warn("In order to create .par files, you need to install PAR::Dist first.");
		return ();
	}
	$self->depends_on('build');
	my $module = $self->module_name;
	$module =~ s/^Padre::Plugin:://;
	$module =~ s/::/-/g;

	return PAR::Dist::blib_to_par(
		name    => $self->dist_name,
		version => $self->dist_version,
		dist    => "$module.par",
	);
}

=pod

=head2 C<installplugin>

Generates the plug-in F<.par> file as the C<plugin> target, but also installs it
into the user's Padre plug-ins directory.

=cut

sub ACTION_installplugin {
	my ($self) = @_;

	$self->depends_on('plugin');

	my $module = $self->module_name;
	$module =~ s/^Padre::Plugin:://;
	$module =~ s/::/-/g;
	my $plugin = "$module.par";

	require Padre;
	return $self->copy_if_modified(
		from   => $plugin,
		to_dir => Padre::Constant::PLUGIN_DIR,
	);
}

1;

__END__

=pod

=head1 SEE ALSO

L<Padre>, L<Padre::Config>

L<Module::Build>

L<PAR> for more on the plug-in system.

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
