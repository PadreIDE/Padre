package Padre::CPAN;

use 5.008;
use strict;
use warnings;
use File::Spec    ();
use File::HomeDir ();
use Padre::Wx     ();

our $VERSION = '0.94';





######################################################################
# Integration with CPAN.pm

my $SINGLETON = undef;

sub new {
	my $class = shift;
	unless ($SINGLETON) {
		require CPAN;
		$SINGLETON = bless {}, $class;
		CPAN::HandleConfig->load(
			be_silent => 1,
		);
		$SINGLETON->{modules} = [ map { $_->id } CPAN::Shell->expand( 'Module', '/^/' ) ];
	}
	return $SINGLETON;
}

sub get_modules {
	my $self  = shift;
	my $regex = shift;
	$regex ||= '^';
	$regex =~ s/ //g;

	my $MAX_DISPLAY = 100;
	my $i           = 0;
	my @modules;
	foreach my $module ( @{ $self->{modules} } ) {
		next if $module !~ /$regex/i;
		$i++;
		last if $i > $MAX_DISPLAY;
		push @modules, $module;
	}
	return \@modules;
}

sub cpan_config {
	my $class = shift;
	my $main  = shift;

	# Locate the CPAN config file(s)
	my $default_dir = '';
	eval {
		require CPAN;
		$default_dir = $INC{'CPAN.pm'};
		$default_dir =~ s/\.pm$//is; # remove .pm
	};

	# Load the main config first
	if ( $default_dir ne '' ) {
		my $core = File::Spec->catfile( $default_dir, 'Config.pm' );
		if ( -e $core ) {
			$main->setup_editors($core);
			return;
		}
	}

	# Fallback to a personal config
	my $user = File::Spec->catfile(
		File::HomeDir->my_home,
		'.cpan', 'CPAN', 'MyConfig.pm'
	);
	if ( -e $user ) {
		$main->setup_editors($user);
		return;
	}

	$main->error( Wx::gettext('Failed to find your CPAN configuration') );
}





######################################################################
# Integration with cpanm

sub install_file {
	my $class = shift;
	my $main  = shift;

	# Ask what we should install
	my $dialog = Wx::FileDialog->new(
		$main,
		Wx::gettext('Select distribution to install'),
		'',                                  # Default directory
		'',                                  # Default file
		'CPAN Packages (*.tar.gz)|*.tar.gz', # wildcard
		Wx::FD_OPEN | Wx::FD_FILE_MUST_EXIST
	);
	$dialog->CentreOnParent;
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetPath;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error( Wx::gettext('Did not provide a distribution') );
		return;
	}

	$class->install_cpanm( $main, $string );
}

sub install_url {
	my $class = shift;
	my $main  = shift;

	# Ask what we should install
	my $dialog = Wx::TextEntryDialog->new(
		$main,
		Wx::gettext('Enter URL to install\ne.g. http://svn.ali.as/cpan/releases/Config-Tiny-2.00.tar.gz'),
		Wx::gettext('Install Local Distribution'),
		'',
	);
	if ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error( Wx::gettext('Did not provide a distribution') );
		return;
	}

	$class->install_cpanm( $main, $string );
}

sub install_cpanm {
	my $class  = shift;
	my $main   = shift;
	my $module = shift;

	# TODO cpanm might come with Padre but if we are dealing with another perl
	# not the one that Padre runs on then we will need to look for cpanm
	# in some other place

	# Find 'cpanm', used to install modules
	require Config;
	my %seen = ();
	my @where =
		grep { defined $_ and length $_ and not $seen{$_}++ }
		map { $Config::Config{$_} }
		qw{
		sitescriptexp
		sitebinexp
		vendorscriptexp
		vendorbinexp
		scriptdirexp
		binexp
	};

	push @where, split /$Config::Config{path_sep}/, $ENV{PATH};

	my $cpanm = '';

	foreach my $dir (@where) {
		my $path = File::Spec->catfile( $dir, 'cpanm' );
		if ( -f $path ) {
			$cpanm = $path;
			last;
		}
	}
	unless ($cpanm) {
		$main->error( Wx::gettext('cpanm is unexpectedly not installed') );
		return;
	}

	# Create the command
	require Padre::Perl;
	my $perl = Padre::Perl::cperl();
	my $cmd  = qq{"$perl" "$cpanm" "$module"};
	$main->run_command($cmd);

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
