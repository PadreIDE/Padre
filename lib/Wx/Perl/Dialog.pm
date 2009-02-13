package Wx::Perl::Dialog;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.05';

use Wx ':everything';

use base 'Wx::Dialog';

=head1 NAME

Wx::Perl::Dialog - Abstract dialog class for simple dialog creation

=head1 SYNOPSIS

	my $layout = [
		[
			[ 'Wx::StaticText', undef,         'Some text entry'],
			[ 'Wx::TextCtrl',   'name_of',     'Default value'  ],
		],
		[
			[ 'Wx::Button',     'ok',           Wx::wxID_OK     ],
			[ 'Wx::Button',     'cancel',       Wx::wxID_CANCEL ],
		],
	];

 	my $dialog = Wx::Perl::Dialog->new(
		parent => $win,
		title  => 'Widgetry dialog',
		layout => $layout,
		width  => [150, 200],
	);

   	return if not $dialog->show_modal;

	my $data = $dialog->get_data; 

	#### You may also create a tabbed dialog for more complex tasks:

	my $tabbed_dialog = Wx::Perl::Dialog->new(
		parent => $win,
		title  => 'Widgetry dialog',
		layout => [ $layout_a, $layout_b, ]
		multipage => {
			auto_ok_cancel => 1,
			ok_widgetid => '_ok_',
			cancel_widgetid => '_cancel_',
			pagenames => [ 'Basic', 'Advanced' ]
		},
	);

Where $win is the Wx::Frame of your application.

=head1 B<WARNING>

This is still an alpha version of the code. It is used mainly by L<Padre> and its
plugins. The API can change without any warning.


=head1 DESCRIPTION

=head2 Layout

The layout is reference to a two dimensional array.
Every element (an array) represents one line in the dialog.

Every element in the internal array is an array that describes a widget.

The first value in each widget description is the type of the widget.

The second value is an identifyer (or undef if we don't need any access to the widget).

The widget will be accessible form the dialog object using $dialog->{_widgets_}{identifyer}

The rest of the values in the array depend on the widget.

=head2 Supported widgets and their parameters

=over 4

=item Wx::StaticText

 3.: "the text",

=item Wx::Button

 3.: button type (stock item such as Wx::wxID_OK or string "&do this")
 
=item Wx::DirPickerCtrl

 3. default directory (must be '')  ???
 4. title to show on the directory browser 

=item Wx::TextCtrl

 3. default value, if any

=item Wx::Treebook

 3. array ref for list of values

=item Wx::FontPickerCtrl

 3. A string describing the font

=item Wx::ColourPickerCtrl

 3. A HTML-compatible colour description string: '#' plus 6 hex digits; i.e. #FF0000

=item Wx::SpinCtrl

 3. Current value (as text value in wxWidgets; an Integer)
 4. Minimum value allowed (Integer)
 5. Maximum value allowed (Integer)

=back

=head2 Multipage Layout (with a Wx::Notebook)

If you pass in a parameter 'multipage', a tabbed dialog will be created using a 
Wx::Notebook. 
The value of the 'layout' parameter will be interpreted as an arrayref where each 
value represents the contents of one page (see section "Layout").

The value of the 'multipage' param should be a hash containing extra options.

=over 4

=item auto_ok_cancel

 If set to a true value, an OK and a CANCEL button will be displayed automatically
 below the tabbed pages.

=item ok_widgetid

 An identifier for the automatically genereated OK button.
 Useful if you want to have access to the button via
 $dialog->{_widgets_}{<ok_widgetid>}

=item cancel_widgetid

 Same as above but for the CANCEL button

=item pagenames

 An arrayref of strings which represent the tab titles. 

=back

=head1 METHODS

=cut

=head2 new

=cut

sub new {
	my ($class, %args) = @_;

	my %default = (
		parent          => undef,
		id              => -1,
		style           => Wx::wxDEFAULT_FRAME_STYLE,
		title           => '',
		pos             => [-1, -1],
		size            => [-1, -1],
		
		top             => 5,
		left            => 5,
		bottom          => 20,
		right           => 5,
		element_spacing => [0, 5],
		multipage       => undef,
	);
	%args = (%default, %args);

	my $self = $class->SUPER::new( @args{qw(parent id title pos size style)});
	if ( defined( $args{multipage} ) ) {
		$self->_build_multipage_layout( map {$_ => $args{$_} } qw(layout width top left bottom right element_spacing multipage) );
		$self->{_multipage_} = $args{multipage};
	}
	else {
		$self->_build_layout( map {$_ => $args{$_} } qw(layout width top left bottom right element_spacing) );
	}
	$self->{_layout_} = $args{layout};

	return $self;
}

=head2 get_data

 my $data = $dialog->get_data;
 
Returns a hash with the keys being the names you gave for each widgets
and the value being the value of that widget in the dialog.

=cut 
 
sub get_data {
	my ( $dialog ) = @_;

	my $layout = $dialog->{_layout_};
	my %data = ();

	if ( $dialog->{_multipage_} ) {
		foreach my $tab ( @$layout ) {
			%data = ( %data, _extract_data( $dialog, $tab ) );
		}
	}
	else {
		%data = _extract_data( $dialog, $layout );
	}

	return \%data;
}

# Internal function
#

sub _extract_data {
	my( $dialog, $layout ) = @_;
	my %data = ();

	foreach my $i (0..@$layout-1) {
		foreach my $j (0..@{$layout->[$i]}-1) {
			next if not @{ $layout->[$i][$j] }; # [] means Expand
			my ($class, $name, $arg, @params) = @{ $layout->[$i][$j] };
			if ($name) {
				next if $class eq 'Wx::Button';

				if ($class eq 'Wx::DirPickerCtrl') {
					$data{$name} = $dialog->{_widgets_}{$name}->GetPath;
				} elsif ($class eq 'Wx::FilePickerCtrl') {
					$data{$name} = $dialog->{_widgets_}{$name}->GetPath;
				} elsif ($class eq 'Wx::Choice') {
					$data{$name} = $dialog->{_widgets_}{$name}->GetSelection;
				} elsif ($class eq 'Wx::FontPickerCtrl') {
					$data{$name} = $dialog->{_widgets_}{$name}->GetSelectedFont->GetNativeFontInfoUserDesc;
				} elsif ($class eq 'Wx::ColourPickerCtrl') {
					$data{$name} = $dialog->{_widgets_}{$name}->GetColour->GetAsString(Wx::wxC2S_HTML_SYNTAX);
				} else {
					$data{$name} = $dialog->{_widgets_}{$name}->GetValue;
				}
			}
		}
	}

	return %data;
}

=head2 show_modal

Helper function that will probably change soon...

 return if not $dialog->show_modal;
 
=cut

sub show_modal {
	my ( $dialog ) = @_;

	my $ret = $dialog->ShowModal;
	if ( $ret eq Wx::wxID_CANCEL ) {
		$dialog->Destroy;
		return;
	} else {
		return $ret;
	}
}

# Internal function
#

sub _build_multipage_layout {
	my ($dialog, %args) = @_;

	my $multipage = $args{multipage};
	delete $args{multipage};

	my $row_cnt = 1;
	if ( defined( $multipage->{auto_ok_cancel} ) && $multipage->{auto_ok_cancel} ) {
		$row_cnt++;
	}

	my $outerBox  = Wx::FlexGridSizer->new( $row_cnt, 1, 0, 0 );
	$outerBox->SetFlexibleDirection( Wx::wxBOTH );
	my $notebook = Wx::Notebook->new(
		$dialog,
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		0,
	);

	foreach my $i (0..@{$args{layout}}-1) {
		my $panel = Wx::Panel->new( $notebook, Wx::wxID_ANY, Wx::wxDefaultPosition, Wx::wxDefaultSize, Wx::wxTAB_TRAVERSAL );
		_build_layout($panel, %args, 'layout', ${$args{layout}}[$i]);
		foreach my $k ( keys %{$panel->{_widgets_}} ) {
			$dialog->{_widgets_}{$k} = $panel->{_widgets_}{$k};
		}
		my $pagename = $i + 1;
		if ( defined $multipage->{pagenames}->[$i] ) {
			$pagename = $multipage->{pagenames}->[$i];
		}
		$notebook->AddPage( $panel, $pagename, ( $i == 0 ? 1 : 0 ) );
	}
	$outerBox->Add( $notebook, 1, wxEXPAND|wxALL, 5 );

	if ( defined( $multipage->{auto_ok_cancel} ) && $multipage->{auto_ok_cancel} ) {
		my $button_row = Wx::BoxSizer->new( Wx::wxHORIZONTAL );

		my $size = Wx::Button::GetDefaultSize;

		my $ok_btn = Wx::Button->new( $dialog, Wx::wxID_OK, '', Wx::wxDefaultPosition, $size );
		if ( my $ok_id = ( defined $multipage->{ok_widgetid} ? $multipage->{ok_widgetid} : '' ) ) {
			$dialog->{_widgets_}{$ok_id} = $ok_btn;
		}

		my $cancel_btn = Wx::Button->new( $dialog, Wx::wxID_CANCEL, '', Wx::wxDefaultPosition, $size );
		if ( my $cancel_id = ( defined $multipage->{cancel_id} ? $multipage->{cancel_id} : '' ) ) {
			$dialog->{_widgets_}{$cancel_id} = $cancel_btn;
		}

		$button_row->Add( $ok_btn, 0, Wx::wxALL|Wx::wxALIGN_CENTER_VERTICAL );
		$button_row->Add( $cancel_btn, 0, Wx::wxALL|Wx::wxALIGN_CENTER_VERTICAL );

		$outerBox->Add( $button_row, 1, wxEXPAND|wxALL, 5 );
	}

	$dialog->SetSizer($outerBox);
	$dialog->Layout();
	$outerBox->Fit($dialog);

	return;
}

# Internal function
#
# $dialog->_build_layout(
#	layout          => $layout,
#	width           => $width,
#	top             => $top
#	left            => $left, 
#	element_spacing => $element_spacing,
#	);
#
sub _build_layout {
	my ($dialog, %args) = @_;

	# TODO make sure width has enough elements to the widest row
	# or maybe we should also check that all the rows has the same number of elements
	my $box  = Wx::BoxSizer->new( Wx::wxVERTICAL );
	
	# Add top margin
	$box->Add(0, $args{top}, 0) if $args{top};

	foreach my $i (0..@{$args{layout}}-1) {
		my $row = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
		$box->Add(0, $args{element_spacing}[1], 0) if $args{element_spacing}[1] and $i;
		$box->Add($row);

		# Add left margin
		$row->Add($args{left}, 0, 0) if $args{left};
		
		foreach my $j (0..@{$args{layout}[$i]}-1) {
			my $width = [$args{width}[$j], -1];

			if (not @{ $args{layout}[$i][$j] } ) {  # [] means Expand
				$row->Add($args{width}[$j], 0, 0, Wx::wxEXPAND, 0);
				next;
			}
			$row->Add($args{element_spacing}[0], 0, 0) if $args{element_spacing}[0] and $j;
			my ($class, $name, $arg, @params) = @{ $args{layout}[$i][$j] };

			my $widget;
			if ($class eq 'Wx::StaticText') {
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width );
			} elsif ($class eq 'Wx::Button') {
				my $s = Wx::Button::GetDefaultSize;
				#print $s->GetWidth, " ", $s->GetHeight, "\n";
				my @args = $arg =~ /[a-zA-Z]/ ? (-1, $arg) : ($arg, '');
				my $size = Wx::Button::GetDefaultSize();
				$widget = $class->new( $dialog, @args, Wx::wxDefaultPosition, $size );
			} elsif ($class eq 'Wx::DirPickerCtrl') {
				my $title = shift(@params) || '';
				$widget = $class->new( $dialog, -1, $arg, $title, Wx::wxDefaultPosition, $width );
				# it seems we cannot set the default directory and 
				# we still have to set this directory in order to get anything back in
				# GetPath
				$widget->SetPath(Cwd::cwd());
			} elsif ($class eq 'Wx::FilePickerCtrl') {
				my $title = shift(@params) || '';
				$widget = $class->new( $dialog, -1, $arg, $title, Wx::wxDefaultPosition, $width );
				$widget->SetPath(Cwd::cwd());
			} elsif ($class eq 'Wx::TextCtrl') {
				my @rest;
				if (@params) {
					$width->[1] = $params[0];
					push @rest, Wx::wxTE_MULTILINE;
				}
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width, @rest );
			} elsif ($class eq 'Wx::CheckBox') {
				my $default = shift @params;
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width, @params );
				$widget->SetValue($default);
			} elsif ($class eq 'Wx::ComboBox') {
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width, @params );
			} elsif ($class eq 'Wx::Choice') {
				$widget = $class->new( $dialog, -1, Wx::wxDefaultPosition, $width, $arg, @params );
				$widget->SetSelection(0);
			} elsif ($class eq 'Wx::StaticLine') {
				$widget = $class->new( $dialog, -1, Wx::wxDefaultPosition, $width, $arg, @params );
			} elsif ($class eq 'Wx::Treebook') {
				my $height = @$arg * 27; # should be height of font
				$widget = $class->new( $dialog, -1, Wx::wxDefaultPosition, [$args{width}[$j], $height] );
				foreach my $name ( @$arg ) {
					my $count = $widget->GetPageCount;
					my $page  = Wx::Panel->new( $widget );
					$widget->AddPage( $page, $name, 0, $count );
				}
			} elsif ($class eq 'Wx::FontPickerCtrl') {
				my $default_val = ( defined $arg ? $arg : '' );
				my $default = Wx::Font->new(Wx::wxNullFont);
				eval {
					$default->SetNativeFontInfoUserDesc($default_val);
				};
				$default = Wx::wxNullFont if $@;
				$widget = $class->new( $dialog, -1, $default, Wx::wxDefaultPosition, $width, Wx::wxFNTP_DEFAULT_STYLE );
			} elsif ($class eq 'Wx::ColourPickerCtrl') {
				my $default_val = ( defined($arg) && $arg ? $arg : '#000000' );
				my $default;
				eval {
					$default = Wx::Colour->new($default_val);
				};
				$default = Wx::Colour->new('#000000') if $@;
				$widget = $class->new( $dialog, -1, $default, Wx::wxDefaultPosition, $width, Wx::wxCLRP_DEFAULT_STYLE );
			} elsif ($class eq 'Wx::SpinCtrl') {
				$widget = $class->new( $dialog, -1, $arg, Wx::wxDefaultPosition, $width, Wx::wxSP_ARROW_KEYS, $params[0], $params[1], $arg );
			} else {
				warn "Unsupported widget $class\n";
				next;
			}

			$row->Add($widget);

			if ($name) {
				$dialog->{_widgets_}{$name} = $widget;
			}
		}
		$row->Add($args{right}, 0, 0, Wx::wxEXPAND, 0) if $args{right}; # margin
	}
	$box->Add(0, $args{bottom}, 0) if $args{bottom}; # margin

	$dialog->SetSizerAndFit($box);

	return;
}

=head1 BUGS

Please submit bugs you find on L<http://padre.perlide.org/>

=head1 COPYRIGHT

Copyright 2008 Gabor Szabo. L<http://www.szabgab.com/>

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

1;
