package Padre::Wx::Style;

# Compiles styles described in configuration into Wx terms that can be quickly
# applied to an editor.

use 5.008;
use strict;
use warnings;
use Padre::Wx            ();
use Padre::Config::Style ();

our $VERSION = '0.90';





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Check params
	unless ( Params::Util::_IDENTIFIER( $self->name ) ) {
		Carp::croak("Missing or invalid style name");
	}
	unless ( Params::Util::_HASH( $self->{data} ) ) {
		Carp::croak("Missing or invalid data style data");
	}
	unless ( Params::Util::_HASH0( $self->{data}->{plain} ) ) {
		Carp::croak("Style does not have a plain type");
	}

	# Compiled types
	$self->{set} = {};

	return $self;
}

sub name {
	$_[0]->{name};
}

sub label {
	$_[0]->{label};
}

sub core {
	$_[0]->{core};
}





######################################################################
# Main Methods

sub apply {
	my $self   = shift;
	my $type   = shift;
	my $editor = shift;

	# Generate the style set if needed
	unless ( $self->{set}->{$type} ) {
		my $data = $self->{data}->{$type} || {};
		my $plain = $self->{data}->{plain};

		# Merge the plain style onto the content type style
		foreach my $key ( keys %$plain ) {
			if ( $key eq 'color' ) {
				my $dcolor = $data->{color};
				my $pcolor = $plain->{color};
				foreach my $color ( keys %$pcolor ) {
					$dcolor->{$color} = $pcolor->{$color};
				}
			} else {
				$data->{$key} = $plain->{$key};
			}
		}

		# Convert the hash into a linear set of style operations
		$self->{set}->{$type} = $self->hash2set($data);
	}

	# Apply the type style to the editor
	my @set = @{ $self->{set}->{$type} };
	while (@set) {
		my $method = shift @set;
		$editor->$method( @{ shift() } );
	}

	return 1;
}





######################################################################
# Support Methods

# Compile a merged style hash down to a set of methods and values
sub hash2set {
	my $self  = shift;
	my $style = shift;
	my @set   = ();

	# Basic foreground and background colours
	my $background = Padre::Wx::color( $style->{background} );
	foreach ( 0 .. Wx::wxSTC_STYLE_DEFAULT ) {
		push @set, StyleSetBackground => [ $_, $background ];
	}
	foreach ( keys %{ $style->{foregrounds} } ) {
		push @set, StyleSetForeground => [ $_, Padre::Wx::color( $style->{foregrounds}->{$_} ) ];
	}

	# Caret colouring
	if ( defined $style->{current_line_foreground} ) {
		push @set, SetCaretForeground => [ Padre::Wx::color( $style->{current_line_foreground} ) ];
	}
	if ( defined $style->{currentline} ) {
		push @set, SetCaretLineBackground => [ Padre::Wx::color( $style->{currentline} ) ];
	}

	# The selection background (if applicable)
	# (The Scintilla official selection background colour is cc0000)
	if ( defined $style->{selection_background} ) {
		push @set, SetSelBackground => [ 1, Padre::Wx::color( $style->{selection_background} ) ];
	}
	if ( defined $style->{selection_foreground} ) {
		push @set, SetSelForeground => [ 1, Padre::Wx::color( $style->{selection_foreground} ) ];
	}

	# Syntax-specific colouring
	foreach my $name ( keys %{ $style->{colors} } ) {
		my $color = $style->{colors}->{$name};
		if ( $name =~ /^PADRE_/ ) {
			$name = "Padre::Constant::$name";
		} elsif (/^wx/) {
			$name = "Wx::$name";
		} else {

			# warn "Invalid style '$name'";
			next;
		}

		# Get the id of the style
		my $id = eval { $name->() };
		if ($@) {

			# warn "Invalid style '$name'";
			next;
		}

		# Apply the style elements
		if ( defined $color->{foreground} ) {
			push @set, StyleSetForeground => $id, Padre::Wx::color( $color->{foreground} );
		}
		if ( defined $color->{background} ) {
			push @set, StyleSetBackground => $id, Padre::Wx::color( $color->{background} );
		}
		if ( defined $color->{bold} ) {
			push @set, StyleSetBold => $id, $color->{bold};
		}
		if ( defined $color->{italics} ) {
			push @set, StyleSetItalic => $id, $color->{italic};
		}
		if ( defined $color->{eolfilled} ) {
			push @set, StyleSetEOLFilled => $id, $color->{eolfilled};
		}
		if ( defined $color->{underlined} ) {
			push @set, StyleSetUnderline => $id, $color->{underline};
		}
	}

	return \@set;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
