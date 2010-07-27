package Padre::Wx::Dialog;

use 5.008;
use strict;
use warnings;

use Wx        ();
use Padre::Wx ();

our $VERSION = '0.68';
our @ISA     = ('Wx::Dialog');

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
		return;
	}

	return $widget;
}

sub add_widget {
	my $self = shift;
	my $name = shift;

	unless ( defined $name and $name ne '' ) {
		return;
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

	return;
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
	return;
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
		return if $w->isa('Wx::Button');
		return if $w->isa('Wx::StaticText');

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
				return;
			}
		}
	}
	return;
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





######################################################################
# Inlined code from Wx::Perl::Dialog

sub new {
	my ( $class, %args ) = @_;

	my %default = (
		parent => undef,
		id     => -1,
		style  => Wx::wxDEFAULT_FRAME_STYLE,
		title  => '',
		pos    => [ -1, -1 ],
		size   => [ -1, -1 ],

		top             => 5,
		left            => 5,
		bottom          => 20,
		right           => 5,
		element_spacing => [ 0, 5 ],
		multipage       => undef,
	);
	%args = ( %default, %args );

	my $self = $class->SUPER::new( @args{qw(parent id title pos size style)} );
	if ( defined( $args{multipage} ) ) {
		$self->_build_multipage_layout( map { $_ => $args{$_} }
				qw(layout width top left bottom right element_spacing multipage) );
		$self->{_multipage_} = $args{multipage};
	} else {
		$self->_build_layout( map { $_ => $args{$_} } qw(layout width top left bottom right element_spacing) );
	}
	$self->{_layout_} = $args{layout};

	return $self;
}

sub get_data {
	my ($dialog) = @_;

	my $layout = $dialog->{_layout_};
	my %data   = ();

	if ( $dialog->{_multipage_} ) {
		foreach my $tab (@$layout) {
			%data = ( %data, _extract_data( $dialog, $tab ) );
		}
	} else {
		%data = _extract_data( $dialog, $layout );
	}

	return \%data;
}

sub _extract_data {
	my $dialog = shift;
	my $layout = shift;
	my %data   = ();

	foreach my $i ( 0 .. @$layout - 1 ) {
		foreach my $j ( 0 .. @{ $layout->[$i] } - 1 ) {
			next if not @{ $layout->[$i][$j] }; # [] means Expand
			my ( $class, $name, $arg, @params ) = @{ $layout->[$i][$j] };
			if ($name) {
				next if $class eq 'Wx::Button';

				if ( $class eq 'Wx::DirPickerCtrl' ) {
					$data{$name} = $dialog->{_widgets_}{$name}->GetPath;
				} elsif ( $class eq 'Wx::FilePickerCtrl' ) {
					$data{$name} = $dialog->{_widgets_}{$name}->GetPath;
				} elsif ( $class eq 'Wx::Choice' ) {
					$data{$name} = $dialog->{_widgets_}{$name}->GetSelection;
				} elsif ( $class eq 'Wx::FontPickerCtrl' ) {
					$data{$name} = $dialog->{_widgets_}{$name}->GetSelectedFont->GetNativeFontInfoUserDesc;
				} elsif ( $class eq 'Wx::ColourPickerCtrl' ) {
					$data{$name} = $dialog->{_widgets_}{$name}->GetColour->GetAsString(Wx::wxC2S_HTML_SYNTAX);
				} else {
					$data{$name} = $dialog->{_widgets_}{$name}->GetValue;
				}
			}
		}
	}

	return %data;
}

sub show_modal {
	my $dialog = shift;
	my $rv     = $dialog->ShowModal;
	if ( $rv eq Wx::wxID_CANCEL ) {
		$dialog->Destroy;
		return;
	}
	return $rv;
}

sub _build_multipage_layout {
	my ( $dialog, %args ) = @_;

	my $multipage = $args{multipage};
	delete $args{multipage};

	my $row_cnt = 1;
	if ( defined( $multipage->{auto_ok_cancel} ) && $multipage->{auto_ok_cancel} ) {
		$row_cnt++;
	}

	my $outerBox = Wx::FlexGridSizer->new( $row_cnt, 1, 0, 0 );
	$outerBox->SetFlexibleDirection(Wx::wxBOTH);
	my $notebook = Wx::Notebook->new(
		$dialog,
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		0,
	);

	foreach my $i ( 0 .. @{ $args{layout} } - 1 ) {
		my $panel =
			Wx::Panel->new( $notebook, Wx::wxID_ANY, Wx::wxDefaultPosition, Wx::wxDefaultSize, Wx::wxTAB_TRAVERSAL );
		_build_layout( $panel, %args, 'layout', ${ $args{layout} }[$i] );
		foreach my $k ( keys %{ $panel->{_widgets_} } ) {
			$dialog->{_widgets_}{$k} = $panel->{_widgets_}{$k};
		}
		my $pagename = $i + 1;
		if ( defined $multipage->{pagenames}->[$i] ) {
			$pagename = $multipage->{pagenames}->[$i];
		}
		$notebook->AddPage( $panel, $pagename, ( $i == 0 ? 1 : 0 ) );
	}
	$outerBox->Add( $notebook, 1, Wx::wxEXPAND | Wx::wxALL, 5 );

	if ( defined( $multipage->{auto_ok_cancel} ) && $multipage->{auto_ok_cancel} ) {
		my $button_row = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

		my $size = Wx::Button::GetDefaultSize;

		my $ok_btn = Wx::Button->new( $dialog, Wx::wxID_OK, '', Wx::wxDefaultPosition, $size );
		my $ok_id = ( defined $multipage->{ok_widgetid} ? $multipage->{ok_widgetid} : '' );
		if ($ok_id) {
			$dialog->{_widgets_}{$ok_id} = $ok_btn;
		}

		my $cancel_btn = Wx::Button->new( $dialog, Wx::wxID_CANCEL, '', Wx::wxDefaultPosition, $size );
		my $cancel_id = ( defined $multipage->{cancel_id} ? $multipage->{cancel_id} : '' );
		if ($cancel_id) {
			$dialog->{_widgets_}{$cancel_id} = $cancel_btn;
		}

		$button_row->Add( $ok_btn,     0, Wx::wxALL | Wx::wxALIGN_CENTER_VERTICAL );
		$button_row->Add( $cancel_btn, 0, Wx::wxALL | Wx::wxALIGN_CENTER_VERTICAL );

		$outerBox->Add( $button_row, 1, Wx::wxEXPAND | Wx::wxALL, 5 );
	}

	$dialog->SetSizer($outerBox);
	$dialog->Layout();
	$outerBox->Fit($dialog);

	return;
}

sub _build_layout {
	my ( $dialog, %args ) = @_;

	# TO DO make sure width has enough elements to the widest row
	# or maybe we should also check that all the rows has the same number of elements
	my $box = Wx::BoxSizer->new(Wx::wxVERTICAL);

	# Add top margin
	$box->Add( 0, $args{top}, 0 ) if $args{top};

	ROW:
	foreach my $i ( 0 .. @{ $args{layout} } - 1 ) { ## Z-TODO: normal for loop
		my $row = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
		$box->Add( 0, $args{element_spacing}[1], 0 ) if $args{element_spacing}[1] and $i;
		$box->Add($row);

		# Add left margin
		$row->Add( $args{left}, 0, 0 ) if $args{left};

		COL:
		foreach my $j ( 0 .. @{ $args{layout}[$i] } - 1 ) { ## Z-TODO: normal for loop
			my $width = [ $args{width}[$j], -1 ];

			if ( not @{ $args{layout}[$i][$j] } ) {         # [] means Expand
				$row->Add( $args{width}[$j], 0, 0, Wx::wxEXPAND, 0 );
				next;
			}
			$row->Add( $args{element_spacing}[0], 0, 0 ) if $args{element_spacing}[0] and $j;
			my ( $class, $name, $arg, @params ) = @{ $args{layout}[$i][$j] };

			my $widget;
			if ( $class eq 'Wx::StaticText' ) {
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width );
			} elsif ( $class eq 'Wx::Button' ) {
				my $s = Wx::Button::GetDefaultSize;

				#print $s->GetWidth, " ", $s->GetHeight, "\n";
				my @args = $arg =~ /[a-zA-Z]/ ? ( -1, $arg ) : ( $arg, '' );
				my $size = Wx::Button::GetDefaultSize();
				$widget = $class->new( $dialog, @args, Wx::wxDefaultPosition, $size );
			} elsif ( $class eq 'Wx::DirPickerCtrl' ) {
				my $title = shift(@params) || '';
				$widget = $class->new( $dialog, -1, $arg, $title, Wx::wxDefaultPosition, $width );

				# it seems we cannot set the default directory and
				# we still have to set this directory in order to get anything back in
				# GetPath
				$widget->SetPath( Cwd::cwd() );
			} elsif ( $class eq 'Wx::FilePickerCtrl' ) {
				my $title = shift(@params) || '';
				$widget = $class->new( $dialog, -1, $arg, $title, Wx::wxDefaultPosition, $width );
				$widget->SetPath( Cwd::cwd() );
			} elsif ( $class eq 'Wx::TextCtrl' ) {
				my @rest;
				if (@params) {
					$width->[1] = $params[0];
					push @rest, Wx::wxTE_MULTILINE;
				}
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width, @rest );
			} elsif ( $class eq 'Wx::CheckBox' ) {
				my $default = shift @params;
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width, @params );
				$widget->SetValue($default);
			} elsif ( $class eq 'Wx::ComboBox' ) {
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width, @params );
			} elsif ( $class eq 'Wx::Choice' ) {
				$widget = $class->new( $dialog, -1, Wx::wxDefaultPosition, $width, $arg, @params );
				$widget->SetSelection(0);
			} elsif ( $class eq 'Wx::StaticLine' ) {
				$width ||= 0;
				$arg   ||= 0;
				$widget = $class->new( $dialog, -1, Wx::wxDefaultPosition, $width, $arg, @params );
			} elsif ( $class eq 'Wx::Treebook' ) {
				my $height = @$arg * 27; # should be height of font
				$widget = $class->new( $dialog, -1, Wx::wxDefaultPosition, [ $args{width}[$j], $height ] );
				foreach my $name (@$arg) {
					my $count = $widget->GetPageCount;
					my $page  = Wx::Panel->new($widget);
					$widget->AddPage( $page, $name, 0, $count );
				}
			} elsif ( $class eq 'Wx::FontPickerCtrl' ) {
				my $default_val = ( defined $arg ? $arg : '' );
				my $default = Wx::Font->new(Wx::wxNullFont);
				eval { $default->SetNativeFontInfoUserDesc($default_val); };
				$default = Wx::wxNullFont if $@;
				$widget = $class->new( $dialog, -1, $default, Wx::wxDefaultPosition, $width, Wx::wxFNTP_DEFAULT_STYLE );
			} elsif ( $class eq 'Wx::ColourPickerCtrl' ) {
				my $default_val = ( defined($arg) && $arg ? $arg : '#000000' );
				my $default;
				eval { $default = Wx::Colour->new($default_val); };
				$default = Wx::Colour->new('#000000') if $@;
				$widget = $class->new( $dialog, -1, $default, Wx::wxDefaultPosition, $width, Wx::wxCLRP_DEFAULT_STYLE );
			} elsif ( $class eq 'Wx::SpinCtrl' ) {
				$widget = $class->new(
					$dialog,    -1, $arg, Wx::wxDefaultPosition, $width, Wx::wxSP_ARROW_KEYS, $params[0],
					$params[1], $arg
				);
			} else {
				warn "Unsupported widget $class\n";
				next;
			}

			$row->Add($widget);

			if ($name) {
				$dialog->{_widgets_}{$name} = $widget;
			}
		}
		$row->Add( $args{right}, 0, 0, Wx::wxEXPAND, 0 ) if $args{right}; # margin
	}
	$box->Add( 0, $args{bottom}, 0 ) if $args{bottom};                    # margin

	$dialog->SetSizerAndFit($box);

	return;
}

1;

__END__

=pod

=head1 NAME

Padre::Wx::Dialog - Dummy Padre wrapper around Wx::Perl::Dialog

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
