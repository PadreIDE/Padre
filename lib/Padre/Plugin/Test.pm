package Padre::Plugin::Test;

use 5.008;
use strict;
use warnings;
use utf8;
use Padre::Constant ();
use Padre::Plugin   ();
use Padre::Wx       ();

our $VERSION = '0.86';
our @ISA     = 'Padre::Plugin';

#####################################################################
# Padre::Plugin Methods

sub padre_interfaces {
	return (
		'Padre::Plugin'   => 0.66,
		'Padre::Constant' => 0.66,
	);
}

sub plugin_name {
	'Testsuite Plugin';
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		'About' => sub { $self->show_about },
	];
}

#####################################################################
# Custom Methods

sub show_about {
	my $self = shift;

	# Locate this plugin
	my $path = File::Spec->catfile(
		Padre::Constant::CONFIG_DIR,
		qw{ plugins Padre Plugin My.pm }
	);

	# Generate the About dialog
	my $about = Wx::AboutDialogInfo->new;
	$about->SetName('Test Plugin');
	$about->SetDescription( <<"END_MESSAGE" );
This plugin doesn't do anything useful itself. It is being used
by the Padre testsuite for testing the plugin API.
END_MESSAGE

	# Show the About dialog
	Wx::AboutBox($about);

	return;
}

sub plugin_enable {
	my $self = shift;

	print "[[[TEST_PLUGIN:enable]]]\n";

	die 'Simulated plugin enable crash' if $ENV{'TESTPLUGIN_ENABLE_CRASH'};

	return 1;
}


sub padre_hooks {
	my $self = shift;

	return {
		before_save => sub {

			print "[[[TEST_PLUGIN:before_save]]] " . join( ', ', @_ ) . "\n";

			return undef;
		},
		after_save => sub {
			my $self = shift;
			my $main = $self->main;

			print "[[[TEST_PLUGIN:after_save]]]\n";
		},
	};

}


1;

__END__

=pod

=head1 NAME

Padre::Plugin::Test - Helper plugin for Padre testsuite

=head1 DESCRIPTION

This plugin doesn't do anything useful itself. It is being used
by the Padre testsuite for testing the plugin API.

=head1 COPYRIGHT & LICENSE

Currently it's copyrighted © 2008-2011 by The Padre development team as
listed in Padre.pm.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
