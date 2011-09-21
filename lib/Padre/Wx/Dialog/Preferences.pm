package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;
use Padre::Locale               ();
use Padre::Document             ();
use Padre::Wx                   ();
use Padre::Wx::Role::Config     ();
use Padre::Wx::FBP::Preferences ();
use Padre::Wx::Style            ();
use Padre::Logger;

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Wx::Role::Config
	Padre::Wx::FBP::Preferences
};





#####################################################################
# Class Methods

# One-shot creation, display and execution.
# Does return the object, but we don't expect anyone to use it.
sub run {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->new($main);

	# Always show the first tab regardless of which one
	# was selected in wxFormBuilder.
	$self->treebook->ChangeSelection(0);

	# Load preferences from configuration
	my $config = $main->config;
	$self->config_load($config);

	# Refresh the sizing, layout and position after the config load
	$self->GetSizer->SetSizeHints($self);
	$self->CentreOnParent;

	# Show the dialog
	if ( $self->ShowModal == Wx::ID_CANCEL ) {
		return;
	}

	# Save back to configuration
	$self->config_save($config);

	# Clean up
	$self->Destroy;
	return 1;
}





#####################################################################
# Constructor and Accessors

sub new {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift->SUPER::new(@_);

	# Set the content of the editor preview
	my $preview = $self->preview;
	$preview->{Document} = Padre::Document->new( mimetype => 'application/x-perl', );
	$preview->{Document}->set_editor( $self->preview );
	$preview->SetText(
		join '',
		map {"$_\n"} "#!/usr/bin/perl",
		"",
		"use strict;",
		"",
		"main();",
		"",
		"exit 0;",
		"",
		"sub main {",
		"\t# some senseles comment",
		"\tmy \$x = \$_[0] ? \$_[0] : 5;",
		"\tprint \"x is \$x\\n\";\n",
		"\tif ( \$x > 5 ) {",
		"\t\treturn 1;",
		"\t} else {",
		"\t\treturn 0;",
		"\t}",
		"}",
		"",
		"__END__",
	);
	$preview->SetReadOnly(1);

	# Build the list of configuration dialog elements.
	# We assume all public dialog elements will match a wx widget with
	# a public method returning it.
	$self->{names} = [ grep { $self->can($_) } $self->config->settings ];

	return $self;
}

sub names {
	return @{ $_[0]->{names} };
}





#####################################################################
# Padre::Wx::Role::Config Methods

sub config_load {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $config = shift;

	# We assume all public dialog elements will match a wx widget with
	# a public method returning it.
	$self->SUPER::config_load( $config, $self->names );

	# Do an initial style refresh of the editor preview
	$self->preview_refresh;

	return 1;
}





######################################################################
# Event Handlers

sub cancel {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Cancel the preferences dialog in Wx
	$self->EndModal(Wx::ID_CANCEL);

	return;
}

sub advanced {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Cancel the preferences dialog since it is not needed
	# but save it first
	$self->config_save( $self->main->config );
	$self->cancel;

	# Show the advanced settings dialog instead
	require Padre::Wx::Dialog::Advanced;
	my $advanced = Padre::Wx::Dialog::Advanced->new( $self->main );
	my $ret      = $advanced->show;

	return;
}

sub guess {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $indent   = $document->guess_indentation_style;

	$self->editor_indent_tab->SetValue( $indent->{use_tabs} );
	$self->editor_indent_tab_width->SetValue( $indent->{tabwidth} );
	$self->editor_indent_width->SetValue( $indent->{indentwidth} );

	return;
}

# We do this the long-hand way for now, as we don't have a suitable
# method for generating proper logical style objects.
sub preview_refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $lock = $self->main->lock('UPDATE');
	my $name = $self->choice('editor_style');
	Padre::Wx::Style->find($name)->apply( $self->preview );
	return;
}





######################################################################
# Support Methods

# Convenience method to get the current value for a single named choice
sub choice {
	my $self    = shift;
	my $name    = shift;
	my $ctrl    = $self->$name() or return;
	my $setting = $self->config->meta($name) or return;
	my $options = $setting->options or return;
	my @results = sort keys %$options;
	return $results[ $ctrl->GetSelection ];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
