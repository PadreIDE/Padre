package Padre::Plugin::Perl5;

use 5.008;
use strict;
use warnings;
use Padre::Wx      ();
use Padre::Plugin  ();
use Padre::Current ();

our $VERSION = '0.41';
our @ISA     = 'Padre::Plugin';

#####################################################################
# Padre::Plugin Methods

sub padre_interfaces {
	'Padre::Plugin' => 0.26, 'Padre::Wx::Main' => 0.26,;
}

sub plugin_name {
	'Perl 5';
}

sub plugin_enable {
	my $self = shift;

	return 1;
}

sub plugin_disable {
	my $self = shift;

	return 1;
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		Wx::gettext("Install Module...") => [
			Wx::gettext("Install CPAN Module")         => 'install_cpan',
			'---'                                      => undef,
			Wx::gettext("Install Local Distribution")  => 'install_file',
			Wx::gettext("Install Remote Distribution") => 'install__url',
			'---'                                      => undef,
			Wx::gettext("Open CPAN Config File")       => 'open_config',
		],
	];
}

#####################################################################
# Plugin Methods

sub install_cpan {
	my $self = shift;
	my $main = shift;
	require Padre::CPAN;
	my $cpan = Padre::CPAN->new;

	require Padre::Wx::CPAN;
	my $cpan_gui = Padre::Wx::CPAN->new( $cpan, $main );
	$cpan_gui->show;
}

sub open_config {
	my $self = shift;
	my $main = shift;

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

	$main->error( Wx::gettext("Failed to find your CPAN configuration") );
}

sub install_file {
	my $self = shift;
	my $main = shift;

	# Ask what we should install
	my $dialog = Wx::FileDialog->new(
		$main,
		Wx::gettext("Select distribution to install"),
		'',                                  # Default directory
		'',                                  # Default file
		'CPAN Packages (*.tar.gz)|*.tar.gz', # wildcard
		Wx::wxFD_OPEN | Wx::wxFD_FILE_MUST_EXIST
	);
	$dialog->CentreOnParent;
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetPath;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error( Wx::gettext("Did not provide a distribution") );
		return;
	}

	$self->install_with_pip( $main, $string );
	return;
}

sub install_url {
	my $self = shift;
	my $main = shift;

	# Ask what we should install
	my $dialog = Wx::TextEntryDialog->new(
		$main,
		Wx::gettext("Enter URL to install\ne.g. http://svn.ali.as/cpan/releases/Config-Tiny-2.00.tar.gz"),
		"pip",
		'',
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	my $string = $dialog->GetValue;
	$dialog->Destroy;
	unless ( defined $string and $string =~ /\S/ ) {
		$main->error( Wx::gettext("Did not provide a distribution") );
		return;
	}

	$self->install_with_pip( $main, $string );
	return;
}

#####################################################################
# Auxiliary Methods

sub install_with_pip {
	my $self   = shift;
	my $main   = shift;
	my $module = shift;

	# Find 'pip', used to install modules
	require File::Which;
	my $pip = scalar File::Which::which('pip');
	unless ( -f $pip ) {
		$main->error( Wx::gettext("pip is unexpectedly not installed") );
		return;
	}

	$main->setup_bindings;

	# Run with the same Perl that launched Padre
	my $perl = Padre->perl_interpreter;
	my $cmd  = qq{"$perl" "$pip" "$module"};
	local $ENV{AUTOMATED_TESTING} = 1;
	Wx::Perl::ProcessStream->OpenProcess( $cmd, 'CPAN_mod', $main );

	return;
}

1;

=pod

=head1 NAME

Padre::Plugin::Perl5 - Perl 5 related code

=head1 DESCRIPTION


=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
