package Padre::Feature;

=pod

=head1 NAME

Padre::Feature - Constants to support currying of feature_* config options

=head1 DESCRIPTION

L<Padre::Config> contains a series of "feature" settings, stored in the
C<feature_*> configuration namespace. These settings are intended to allow
the optional removal of unwanted features (and their accompanying bloat),
and the optional inclusion of experimental features (and their accompanying
instability).

To allow both the removal and inclusion of option features to be done
efficiently, Padre checks the configuration at startup time and cooks these
preferences down into constants in the Padre::Feature namespace.

With this mechanism the code for each feature can be compiled away entirely when
it is not in use, making Padre faster and recovering the memory that these
features would otherwise consume.

The use of a dedicated module for this purpose ensures this config to constant
compilation is done in a single place, and provides a module dependency target
for modules that use this system.

=cut

# NOTE: Do not move this to Padre::Constant.
# This module depends on Padre::Config, which depends on Padre::Constant,
# so putting these constants in Padre::Constant would create a circular
# dependency.

use 5.008;
use strict;
use warnings;
use constant      ();
use Padre::Config ();

our $VERSION = '0.94';

my $config = Padre::Config->read;

constant->import(
	{

		# Bloaty features users can disable
		BOOKMARK           => $config->feature_bookmark,
		CURSORMEMORY       => $config->feature_cursormemory,
		DEBUGGER           => $config->feature_debugger,
		FOLDING            => $config->feature_folding,
		FONTSIZE           => $config->feature_fontsize,
		SESSION            => $config->feature_session,
		CPAN               => $config->feature_cpan,
		VCS                => $config->feature_vcs_support,
		DIFF_DOCUMENT      => $config->feature_document_diffs,
		SYNTAX_ANNOTATIONS => $config->feature_syntax_check_annotations,

		# Experimental features users can enable
		COMMAND         => $config->feature_command,
		SYNC            => $config->feature_sync,
		QUICK_FIX       => $config->feature_quick_fix,
		STYLE_GUI       => $config->feature_style_gui,
		DIFF_WINDOW     => $config->feature_diff_window,
		DEVEL_ENDSTATS  => $config->feature_devel_endstats,
		DEVEL_TRACEUSE  => $config->feature_devel_traceuse,
	}
);

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
