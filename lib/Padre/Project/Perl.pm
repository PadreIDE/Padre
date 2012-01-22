package Padre::Project::Perl;

use 5.008;
use strict;
use warnings;
use File::Spec     ();
use Padre::Util    ();
use Padre::Project ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.88';
our @ISA        = 'Padre::Project';





######################################################################
# Configuration and Intuition

sub headline {
	$_[0]->{headline}
		or $_[0]->{headline} = $_[0]->_headline;
}

sub _headline {
	my $self = shift;
	my $root = $self->root;

	# The intuitive approach is to find the top-most .pm file
	# in the lib directory.
	my $cursor = 'lib';
	my $dir    = File::Spec->catdir( $root, $cursor );
	unless ( -d $dir ) {

		# Weird-looking Perl distro...
		return undef;
	}

	while (1) {
		local *DIRECTORY;
		opendir( DIRECTORY, $dir ) or last;
		my @files = readdir(DIRECTORY) or last;
		closedir(DIRECTORY) or last;

		# Can we find a single dominant module?
		my @modules = grep {/\.pm\z/} @files;
		if ( @modules == 1 ) {
			return File::Spec->catfile( $cursor, $modules[0] );
		}

		# Can we find a single subdirectory without punctuation to descend?
		# We use a slightly unusual checking process, because we want to abort
		# as soon as we see the second subdirectory (because this scanning
		# happens in the foreground and we don't want to overblock)
		my $candidate = undef;
		foreach my $file (@files) {
			next if $file =~ /\./;
			my $path = File::Spec->catdir( $dir, $file );
			next unless -d $path;
			if ($candidate) {

				# Shortcut, more than one
				last;
			} else {
				$candidate = $path;
			}
		}

		# Did we find a single candidate?
		last unless $candidate;
		$cursor = $candidate;
		$dir    = File::Spec->catdir( $root, $cursor );
	}

	return undef;
}

sub version {
	my $self = shift;

	# Look for a version declaration in the headline module for the project.
	my $file = $self->headline_path;
	return undef unless defined $file;
	Padre::Util::parse_variable( $file, 'VERSION' );
}

sub module {
	$_[0]->{module}
		or $_[0]->{module} = $_[0]->_module;
}

# Attempts to determine a headline module name for the project
sub _module {
	my $self = shift;

	# Look for a package declaration in the headline module for the project
	my $file = $self->headline_path;
	return undef unless defined $file;
	local $/ = "\n";
	local $_;
	open( my $fh, '<', $file ) #-# no critic (RequireBriefOpen)
		or die "Could not open '$file': $!";

	# Look for a package declaration somewhere in the first 10 lines.
	# After that, it's probably more likely to be superfluous than real.
	my $lines  = 0;
	my $result = undef;
	while (<$fh>) {
		if (m{^ \s* package \s+ (\w[\w\:\']*) }x) {
			$result = $1;
			last;
		}
		last if ++$lines > 10;
	}
	close $fh;

	return $result;
}

# Attempts to determine a distribution name (e.g. Foo-Bar) for the project
sub distribution {
	my $self = shift;
	my $name = $self->module;
	return undef unless defined $name;

	# Transform using the most common pattern
	$name =~ s/(?:::|')/-/g;
	return $name;
}





######################################################################
# Directory Integration

sub ignore_rule {
	my $super = shift->SUPER::ignore_rule(@_);
	return sub {

		# Do the checks from our parent
		return 0 unless $super->();

		# In a distribution, we can ignore more things
		return 0 if $_->{name} =~ /^(?:blib|_build|inc|Makefile(?:\.old)?|pm_to_blib|MYMETA\.(?:yml|json))\z/;

		# It is fairly common to get bogged down in NYTProf output
		return 0 if $_->{name} =~ /^nytprof(?:\.out)?\z/;

		# Everything left, so we show it
		return 1;
	};
}

sub ignore_skip {
	my $self = shift;
	my $rule = $self->SUPER::ignore_skip(@_);

	# Ignore typical build files
	push @$rule, '(?:^|\\/)(?:blib|_build|inc|Makefile(?:\.old)?|pm_to_blib|MYMETA\.(?:yml|json))\z';

	# Ignore the enormous NYTProf output
	push @$rule, '(?:^|\\/)nytprof(?:\.out)?\z';

	return $rule;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
