package Padre::Wx::Dialog;

use 5.008;
use strict;
use warnings;
use Wx::Perl::Dialog ();

our $VERSION = '0.43';
our @ISA     = 'Wx::Perl::Dialog';

sub create_widget {
	my $self        = shift;
	my $widgetClass = shift;
	my $param       = shift;

	my $parent = $param->[0];

	my $widget;
	if ( $widgetClass eq 'Wx::StaticText' ) {
		$widget = $widgetClass->new( $parent, Wx::wxID_STATIC, $param->[1] );
	} elsif ( $widgetClass eq 'Wx::Button' ) {
		$widget = $widgetClass->new( $parent, -1, $param->[1] );
	} elsif ( $widgetClass eq 'Wx::DirPickerCtrl' ) {
		my $title = $param->[1] || '';
		$widget = $widgetClass->new( $parent, -1, '', $param->[2] );
		$widget->SetPath( $param->[1] || Cwd::cwd() );
	} elsif ( $widgetClass eq 'Wx::FilePickerCtrl' ) {
		$widget = $widgetClass->new( $parent, -1, $param->[1], $param->[2] );
		$widget->SetPath( Cwd::cwd() );
	} elsif ( $widgetClass eq 'Wx::TextCtrl' ) {
		if ( $param->[2] ) {
			$widget = $widgetClass->new(
				$parent,
				-1,
				$param->[1],
				Wx::wxDefaultPosition,
				Wx::wxDefaultSize,
				$param->[2]
			);
		} else {
			$widget = $widgetClass->new( $parent, -1, $param->[1] );
		}
	} elsif ( $widgetClass eq 'Wx::CheckBox' ) {
		$widget = $widgetClass->new( $parent, -1, $param->[2] );
		$widget->SetValue( $param->[1] );
	} elsif ( $widgetClass eq 'Wx::ComboBox' ) {
		$widget = $widgetClass->new( $parent, -1, $param->[1] );
	} elsif ( $widgetClass eq 'Wx::Choice' ) {
		my $ary_size = scalar @$param;
		$widget = $widgetClass->new(
			$parent,
			-1,
			Wx::wxDefaultPosition,
			Wx::wxDefaultSize,
			$param->[1],
			( $ary_size > 3 ? @{$param}[ 2 .. $ary_size ] : () )
		);
		$widget->SetSelection(0);
	} elsif ( $widgetClass eq 'Wx::StaticLine' ) {
		$widget = $widgetClass->new(
			$parent,
			Wx::wxID_STATIC,
			Wx::wxDefaultPosition,
			Wx::wxDefaultSize,
			$param->[1]
		);
	} elsif ( $widgetClass eq 'Wx::FontPickerCtrl' ) {
		my $default_val = ( defined $param->[1] and $param->[1] ne '' ? $param->[1] : '' );
		my $default = Wx::Font->new(Wx::wxNullFont);
		eval { $default->SetNativeFontInfoUserDesc($default_val); };
		$default = Wx::wxNullFont if $@;
		$widget = $widgetClass->new(
			$parent,
			-1,
			$default,
			Wx::wxDefaultPosition,
			Wx::wxDefaultSize,
			Wx::wxFNTP_DEFAULT_STYLE
		);
	} elsif ( $widgetClass eq 'Wx::ColourPickerCtrl' ) {
		my $default_val = ( defined( $param->[1] ) && $param->[1] ne '' ? $param->[1] : '#000000' );
		my $default;
		eval { $default = Wx::Colour->new($default_val); };
		$default = Wx::Colour->new('#000000') if $@;
		$widget = $widgetClass->new(
			$parent,
			-1,
			$default,
			Wx::wxDefaultPosition,
			Wx::wxDefaultSize,
			Wx::wxCLRP_DEFAULT_STYLE
		);
	} elsif ( $widgetClass eq 'Wx::SpinCtrl' ) {
		$widget = $widgetClass->new(
			$parent,
			-1,
			$param->[1],
			Wx::wxDefaultPosition,
			Wx::wxDefaultSize,
			Wx::wxSP_ARROW_KEYS,
			$param->[2],
			$param->[3],
			$param->[1]
		);
	} else {

		#warn "Unsupported widget $widgetClass\n";
		return undef;
	}

	return $widget;
}

sub add_widget {
	my $self = shift;
	my $name = shift;

	unless ( defined $name and $name ne '' ) {
		return undef;
	}

	my $widget = '';
	if (    defined $_[0]
		and ref( $_[0] )
		and $_[0]->isa('Wx::Control') )
	{
		$widget = shift;
	} else {
		$widget = $self->create_widget(@_);
	}

	if ( $widget->isa('Wx::Control') ) {
		if ( defined $self->{_widgets_}->{$name} ) {
			delete $self->{_widgets_}->{$name};
		}
		$self->{_widgets_}->{$name} = $widget;
		return $widget;
	}

	return undef;
}

sub get_widget {
	my $self = shift;
	my $name = shift;

	if ( defined $name and $name ne '' ) {
		if ( defined $self->{_widgets_}->{$name}
			and $self->{_widgets_}->{$name}->isa('Wx::Control') )
		{
			return $self->{_widgets_}->{$name};
		} elsif ( defined $self->{_widgets_}->{$name} ) {
			delete $self->{_widgets_}->{$name};
		}
	}
	return undef;
}

sub get_widget_value {
	my $self = shift;
	my $name = shift;

	if (   defined($name)
		&& $name ne ''
		&& defined $self->{_widgets_}->{$name}
		&& $self->{_widgets_}->{$name}->isa('Wx::Control') )
	{
		my $w = $self->{_widgets_}->{$name};
		return undef if $w->isa('Wx::Button');
		return undef if $w->isa('Wx::StaticText');

		if ( $w->isa('Wx::DirPickerCtrl') ) {
			return $w->GetPath;
		} elsif ( $w->isa('Wx::FilePickerCtrl') ) {
			return $w->GetPath;
		} elsif ( $w->isa('Wx::ComboBox') ) {
			return $w->GetValue;
		} elsif ( $w->isa('Wx::Choice') ) {
			return $w->GetSelection;
		} elsif ( $w->isa('Wx::FontPickerCtrl') ) {
			return $w->GetSelectedFont->GetNativeFontInfoUserDesc;
		} elsif ( $w->isa('Wx::ColourPickerCtrl') ) {
			return $w->GetColour->GetAsString(Wx::wxC2S_HTML_SYNTAX);
		} elsif ( $w->isa('Wx::TextCtrl') ) {
			return ( defined $w->GetValue ) ? $w->GetValue : '';
		} else {
			if ( $w->can('GetValue') ) {
				return $w->GetValue;
			} else {
				return undef;
			}
		}
	}
	return undef;
}

sub get_widgets_values {
	my $self = shift;

	my $data = {};
	foreach my $w ( keys %{ $self->{_widgets_} } ) {
		$data->{$w} = $self->get_widget_value($w);
	}

	return $data;
}

sub fill_panel_by_table {
	my $self  = shift;
	my $panel = shift;
	my $table = shift;

	my $stdStyle = Wx::wxALIGN_LEFT | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL;

	my $fgs = '';
	unless ( $fgs = $panel->GetSizer ) {
		my $cols = 0;
		foreach my $row (@$table) {
			if ( scalar(@$row) > $cols ) {
				$cols = scalar(@$row);
			}
		}
		$fgs = Wx::FlexGridSizer->new( 0, $cols, 0, 0 );
		$panel->SetSizer($fgs);
	}

	foreach my $row (@$table) {
		foreach my $col (@$row) {
			if ( scalar @$col == 0 ) {
				$fgs->Add( 0, 0 );
				next;
			}

			my $class = shift(@$col);
			my $name  = shift(@$col);

			my $style = $stdStyle;
			if (    $class ne 'Wx::StaticText'
				and $class ne 'Wx::CheckBox' )
			{
				$style |= Wx::wxEXPAND;
			}

			if ( !$name ) {
				$fgs->Add(
					$self->create_widget( $class, [ $panel, @$col ] ),
					0, $style, 3
				);
			} else {
				my $tmpWidget = $self->add_widget( $name, $class, [ $panel, @$col ] );
				$fgs->Add( $tmpWidget, 0, $style, 3 );
			}
		}
	}

	return;
}

1;

__END__

=pod

=head1 NAME

Padre::Wx::Dialog - Dummy Padre wrapper around Wx::Perl::Dialog

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
