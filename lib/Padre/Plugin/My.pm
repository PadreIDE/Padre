package Padre::Plugin::My;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

use base 'Padre::Plugin';

our $VERSION = '0.20';





#####################################################################
# Padre::Plugin Methods

use padre_interfaces {
	'Padre::Plugin' => '0.19',
}

sub plugin_name {
	return 'My Plugin';
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		'About' => sub { $self->about },
		# 'Another Menu Entry' => sub { $self->about },
		# 'A Sub-Menu...' => [
		#     'Sub-Menu Entry' => sub { $self->about },
		# ],
	];
}





#####################################################################
# Custom Methods

sub about {
	my $self = shift;

	# Locate this plugin
	my $path = File::Spec->catfile(
		Padre->ide->config_dir,
		qw{ plugins Padre Plugin My.pm }
	);

	# Generate the About dialog
	my $about = Wx::AboutDialogInfo->new;
	$about->SetName("My Plugin");
	$about->SetDescription( <<"END_MESSAGE" );
The philosophy behind Padre is that every Perl programmer
should be able to easily modify and improve their own editor.

To help you get started, we've provided you with your own plugin.

It is located in your configuration directory at:
$path
Open it with with Padre and you'll see an explanation on how to add items.
END_MESSAGE

	# Show the About dialog
	Wx::AboutBox( $about );

	return;
}

1;
