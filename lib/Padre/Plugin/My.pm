package Padre::Plugin::My;

use 5.010;
use strict;
use warnings;
use utf8;
use Padre::Plugin   ();

our $VERSION = '1.02';
use parent qw(Padre::Plugin);



#######
# Define Padre Interfaces required
#######
sub padre_interfaces {
	return (
		'Padre::Plugin'   => 0.94,
		'Padre::Constant' => 0.94,
		'Padre::Unload'   => 0.94,
	);
}

# Child modules we need to unload when disabled
use constant CHILDREN => qw{
	Padre::Plugin::My
};

#######
# Called by padre to know the plugin name
#######
sub plugin_name {
	return Wx::gettext('My Plugin');
}


sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		'About' => sub { $self->show_about },

		# 'Another Menu Entry' => sub { $self->other_method },
		# 'A Sub-Menu...' => [
		#     'Sub-Menu Entry' => sub { $self->yet_another_method },
		# ],
	];
}

# Core plugins may reuse the page icon
sub plugin_icon {
	require Padre::Wx::Icon;
	Padre::Wx::Icon::find('logo');
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
	$about->SetName('My Plug-in');
	$about->SetDescription( <<"END_MESSAGE" );
The philosophy behind Padre is that every Perl programmer
should be able to easily modify and improve their own editor.

To help you get started, we've provided you with your own plug-in.

It is located in your configuration directory at:
$path
Open it with with Padre and you'll see an explanation on how to add items.
END_MESSAGE

	# Show the About dialog
	Wx::AboutBox($about);

	return;
}

sub other_method {
	my $self = shift;
	my $main = $self->main;

	$main->message( 'Hi from My Plugin', 'Other method' );

	# my $name = $main->prompt('What is your name?', 'Title', 'UNIQUE_KEY_TO_REMEMBER');
	# $main->message( "Hello $name", 'Welcome' );

	# my $doc   = Padre::Current->document;
	# my $text  = $doc->text_get;
	# my $count = length($text);
	# my $filename = $doc->filename;
	# $main->message( "Filename: $filename\nCount: $count", 'Current file' );

	# my $doc   = Padre::Current->document;
	# my $text  = $doc->text_get;
	# $text     =~ s/[ \t]+$//m;
	# $doc->text_set( $text );

	return;
}

########
# plugin_disable
########
sub plugin_disable {
	my $self = shift;

	# Close the dialog if it is hanging around
	# $self->clean_dialog;

	# Unload all our child classes
	for my $package (CHILDREN) {
		require Padre::Unload;
		Padre::Unload->unload($package);
	}

	$self->SUPER::plugin_disable(@_);

	return 1;
}

1;

__END__

=pod

=head1 NAME

Padre::Plugin::My - My personal plug-in

=head1 DESCRIPTION

This is your personal plug-in. Update it to fit your needs. And if it
does interesting stuff, please consider sharing it on C<CPAN>!

=head1 COPYRIGHT & LICENSE

Currently it's copyrighted (c) 2008-2010 by The Padre development team as
listed in Padre.pm... But update it and it will become copyrighted (c) You
C<< <you@example.com> >>! How exciting! :-)

=cut

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
