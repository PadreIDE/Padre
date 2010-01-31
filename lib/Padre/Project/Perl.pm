package Padre::Project::Perl;

# This is not usable yet

use 5.008;
use strict;
use warnings;
use Padre::Project             ();
use Padre::Project::Perl::MI   ();
use Padre::Project::Perl::MB   ();
use Padre::Project::Perl::DZ   ();
use Padre::Project::Perl::EUMM ();

our $VERSION = '0.55';
our @ISA     = 'Padre::Project';

sub from_file {
	my $class = shift;

	# Check the file argument
	my $focus_file = shift;
	return unless -f $focus_file;

	# Search upwards from the file to find the project root
	my ( $v, $d, $f ) = File::Spec->splitpath($focus_file);
	my @d = File::Spec->splitdir($d);
	pop @d if $d[-1] eq '';
	foreach ( reverse 0 .. $#d ) {
		my $dir = File::Spec->catdir( @d[ 0 .. $_ ] );

		# Check for Dist::Zilla support
		my $dist_ini = File::Spec->catpath( $v, $dir, 'dist.ini' );
		if ( -f $dist_ini ) {
			return Padre::Project::Perl::DZ->new(
				root     => File::Spec->catpath( $v, $dir ),
				dist_ini => $dist_ini,
			);
		}

		# Check for Module::Build support
		my $build_pl = File::Spec->catpath( $v, $dir, 'Build.PL' );
		if ( -f $build_pl ) {
			return Padre::Project::Perl::MB->new(
				root     => File::Spec->catpath( $v, $dir ),
				build_pl => $build_pl,
			);
		}

		# Check for ExtUtils::MakeMaker and Module::Install support
		my $makefile_pl = File::Spec->catpath( $v, $dir, 'Makefile.PL' );
		if ( -f $makefile_pl ) {
			# Differentiate between Module::Install and ExtUtils::MakeMaker
			return Padre::Project::Perl::EUMM->new(
				root        => File::Spec->catpath( $v, $dir ),
				makefile_pl => $makefile_pl,
			);
		}

		# Fall back to looking for null projects
		my $padre_yml = File::Spec->catpath( $v, $dir, 'padre.yml' );
		if ( -f $padre_yml ) {
			return Padre::Project::Perl->new(
				root => File::Spec->catpath( $v, $dir ),
				padre_yml => $padre_yml,
			);
		}

		return;
	}
}





######################################################################
# Directory Integration

sub ignore_rule {
	return sub {

		# Default filter as per normal
		if ( $_->{name} =~ /^\./ ) {
			return 0;
		}

		# In a distribution, we can ignore more things
		if ( $_->{name} =~ /^(?:blib|_build|inc|Makefile|pm_to_blib)\z/ ) {
			return 0;
		}

		# Everything left, we show
		return 1;
	};
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
