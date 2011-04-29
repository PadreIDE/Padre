package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;
use Padre::Locale                ();
use Padre::Document              ();
use Padre::Wx                    ();
use Padre::Wx::FBP::Preferences2 ();
use Padre::Logger;

our $VERSION = '0.85';
our @ISA     = 'Padre::Wx::FBP::Preferences2';





#####################################################################
# Constructor and Accessors

sub new {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift->SUPER::new(@_);

	# Set the content of the editor preview
	$self->preview->{Document} = Padre::Document->new(
		mimetype => 'application/x-perl',
	);
	$self->preview->{Document}->set_editor($self->preview);
	$self->preview->SetText(
		join '', map { "$_\n" }
		"#!/usr/bin/perl",
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
		"\tif ( \$x > 5 ) {",
		"\t\treturn 1;",
		"\t} else {",
		"\t\treturn 0;",
		"\t}",
		"}",
		"",
		"__END__",
	);

	return $self;
}

# One-shot creation, display and execution.
# Does return the object, but we don't expect anyone to use it.
sub run {
	my $class  = shift;
	my $main   = shift;
	my $config = $main->config;
	my $self   = Padre::Wx::Dialog::Preferences->new($main);
	$self->load( $main->config );
	$self->CentreOnParent;
	unless ( $self->ShowModal == Wx::wxID_CANCEL ) {
		$self->save( $main->config );
	}
	return $self;
}





#####################################################################
# Load and Save

sub load {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $config = shift;

	# Iterate over the configuration entries and apply the
	# configuration state to the dialog.
	foreach my $name ( $config->settings ) {
		next unless $self->can($name);

		# Get the Wx element for this option
		my $setting = $config->meta($name);
		my $value   = $config->$name();
		my $ctrl    = $self->$name();

		# Apply this one setting to this one widget
		if ( $ctrl->isa('Wx::CheckBox') ) {
			$ctrl->SetValue($value);

		} elsif ( $ctrl->isa('Wx::TextCtrl') ) {
			$ctrl->SetValue($value);

		} elsif ( $ctrl->isa('Wx::SpinCtrl') ) {
			$ctrl->SetValue($value);

		} elsif ( $ctrl->isa('Wx::ColourPickerCtrl') ) {
			$ctrl->SetColour( Padre::Wx::color($value) );

		} elsif ( $ctrl->isa('Wx::FontPickerCtrl' ) ) {
			my $font = Wx::Font->new(Wx::wxNullFont);
			local $@;
			eval {
				$font->SetNativeFontInfoUserDesc($value);
			};
			$font = Wx::Font->new(Wx::wxNullFont) if $@;
			$ctrl->SetSelectedFont($font);

		} elsif ( $ctrl->isa('Wx::Choice') ) {
			my $options = $setting->options;
			if ($options) {
				$ctrl->Clear;

				# NOTE: This assumes that the list will not be
				# sorted in Wx via a style flag and that the
				# order of the fields should be that of the key
				# and not of the translated label.
				# Doing sort in Wx will probably break this.
				foreach my $option ( sort keys %$options ) {
					my $label = $options->{$option};
					$ctrl->Append(
						Wx::gettext($label),
						$option,
					);
					next unless $option eq $value;
					$ctrl->SetSelection( $ctrl->GetCount - 1 );
				}
			}

		} else {
			next;
		}
	}

	# Sync the editor preview to the current config
	$self->preview->set_preferences;

	### HACK
	# Backup the editor style
	$self->{original_style} = $config->editor_style;

	return 1;
}

sub save {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $config = shift;

	# Lock a bunch of stuff so the apply handlers run quickly
	my $lock = $self->main->lock('UPDATE', 'REFRESH', 'DB');

	# Apply the changes to the configuration, if any
	my $diff    = $self->diff($config) or return;
	my $current = $self->current;
	foreach my $name ( sort keys %$diff ) {
		$config->apply( $name, $diff->{$name}, $current );
	}

	# Save the config file
	$config->write;

	return;
}

sub diff {
	my $self   = shift;
	my $config = shift;
	my %diff   = ();

	# Iterate over the configuration entries and apply the
	# configuration state to the dialog.
	foreach my $name ( $config->settings ) {
		next unless $self->can($name);

		# Get the Wx element for this option
		my $setting = $config->meta($name);
		my $old     = $config->$name();
		my $ctrl    = $self->$name();

		### HACK
		# Get the "old" value from the backed up copy of the style
		if ( $name eq 'editor_style' ) {
			$old = $self->{original_style};
		}

		# Don't capture options that are not shown,
		# as this may result in falsely clearing them.
		next unless $ctrl->IsEnabled;

		# Extract the value from the control
		my $value = undef;
		if ( $ctrl->isa('Wx::CheckBox') ) {
			$value = $ctrl->GetValue ? 1 : 0;

		} elsif ( $ctrl->isa('Wx::TextCtrl') ) {
			$value = $ctrl->GetValue;

		} elsif ( $ctrl->isa('Wx::SpinCtrl') ) {
			$value = $ctrl->GetValue;

		} elsif ( $ctrl->isa('Wx::ColourPickerCtrl') ) {
			$value = $ctrl->GetColour->GetAsString(Wx::wxC2S_HTML_SYNTAX);
			$value =~ s/^#// if defined $value;

		} elsif ( $ctrl->isa('Wx::FontPickerCtrl') ) {
			$value = $ctrl->GetSelectedFont->GetNativeFontInfoUserDesc;

		} elsif ( $ctrl->isa('Wx::Choice') ) {
			my $options = $setting->options;
			if ($options) {
				my @k = sort keys %$options;
				my $i = $ctrl->GetSelection;
				$value = $k[$i];
			}
		} else {

			# To be completed
		}

		# Skip if null
		next unless defined $value;
		next if $value eq $old;
		$diff{$name} = $value;
	}

	return unless %diff;
	return \%diff;
}

# Convenience method to get the current value for a single named choice
sub choice {
	my $self    = shift;
	my $name    = shift;
	my $ctrl    = $self->$name()             or return;
	my $setting = $self->config->meta($name) or return;
	my $options = $setting->options          or return;
	my @results = sort keys %$options;
	return $results[ $ctrl->GetSelection ];
}





######################################################################
# Event Handlers

sub cancel {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;

	# Apply the original style
	my $style = delete $self->{original_style};
	$self->main->action("view.style.$style");

	# Cancel the preferences dialog in Wx
	$self->EndModal(Wx::wxID_CANCEL);

	return;
}

sub advanced {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Cancel the preferences dialog since it is not needed
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
	my $self    = shift;
	my $config  = $self->config;
	my $preview = $self->preview;

	# Set the colour of the current line (if visible)
	if ( $config->editor_currentline ) {
		$preview->SetCaretLineBackground(
			$self->editor_currentline_color->GetColour
		);
	}

	# Set the font for the editor
	my $font = $self->editor_font->GetSelectedFont;
	$preview->SetFont($font);
	$preview->StyleSetFont( Wx::wxSTC_STYLE_DEFAULT, $font );

	# Set the right margin if applicable
	if ( $self->editor_right_margin_enable->GetValue ) {
		$preview->SetEdgeColumn( $self->editor_right_margin_column );
		$preview->SetEdgeMode(Wx::wxSTC_EDGE_LINE);
	} else {
		$preview->SetEdgeMode(Wx::wxSTC_EDGE_NONE);
	}

	# Apply the style (but only if we can do so safely)
	if ( $self->{original_style} ) {
		my $style = $self->choice('editor_style');
		Padre::Current->main->action("view.style.$style");
		$preview->set_preferences;
	}

	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

