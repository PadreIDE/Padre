package Padre::Wx::Dialog::RegexEditor;

# The Regex Editor for Padre

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::Icon            ();
use Padre::Wx::Role::MainChild ();

our $VERSION = '0.56';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};


######################################################################
# Constructor

sub new {
	my $class  = shift;
	my $parent = shift;

	# Create the basic object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext('Regex Editor'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Set basic dialog properties
	$self->SetIcon(Padre::Wx::Icon::PADRE);
	$self->SetMinSize( [ 350, 550 ] );

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	# Create the controls
	$self->_create_controls($sizer);

	# Bind the control events
	$self->_bind_events;

	# Tune the size and position it appears
	$self->SetSizer($sizer);
	$self->Fit;
	$self->CentreOnParent;

	return $self;
}


#
# A private method that returns a hash of regex groups along with their meaning
#
sub _regex_groups {
	my $self = shift;

	return (
		'00' => {
			label => Wx::gettext('Character Classes'),
			value => {
				'00.'  => Wx::gettext('Any character except a newline'),
				'01\d' => Wx::gettext('Any decimal digit'),
				'02\D' => Wx::gettext('Any non-digit'),
				'03\s' => Wx::gettext('Any whitespace character'),
				'04\S' => Wx::gettext('Any non-whitespace character'),
				'05\w' => Wx::gettext('Any word character'),
				'06\W' => Wx::gettext('Any non-word character'),
			}
		},
		'01' => {
			label => Wx::gettext('Quantifiers'),
			value => {
				'00*'     => Wx::gettext('Zero or more of the preceding block'),
				'01+'     => Wx::gettext('One or more of the preceding block'),
				'02?'     => Wx::gettext('Zero or one of the preceding block'),
				'03{m}'   => Wx::gettext('Exactly m of the preceding block'),
				'04{m,n}' => Wx::gettext('m to n of the preceding block'),
			}
		},
		'02' => {
			label => Wx::gettext('Miscellaneous'),
			value => {
				'00|'   => Wx::gettext('Alternation'),
				'01[ ]' => Wx::gettext('Character set'),
				'02^'   => Wx::gettext('Beginning of line'),
				'03$'   => Wx::gettext('End of line'),
				'04\b'  => Wx::gettext('A word boundary'),
				'05\B'  => Wx::gettext('Not a word boundary'),
			}
		},
		'03' => {
			label => Wx::gettext('Grouping constructs'),
			value => {
				'00( )'   => Wx::gettext('A group'),
				'01(?: )' => Wx::gettext('Non-capturing group'),
				'02(?= )' => Wx::gettext('Positive lookahead assertion'),
				'03(?! )' => Wx::gettext('Negative lookahead assertion'),
				'04\n'    => Wx::gettext('Backreference to the nth group'),
			}
		}
	);
}

sub _create_controls {
	my ( $self, $sizer ) = @_;

	# Dialog Controls

	my $regex_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Regular Expression:') );

	$self->{regex} = Wx::TextCtrl->new(
		$self, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxTE_MULTILINE | Wx::wxNO_FULL_REPAINT_ON_RESIZE
	);

	my $substitute_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Substitute text with:') );
	$self->{substitute} = Wx::TextCtrl->new(
		$self, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxTE_MULTILINE | Wx::wxNO_FULL_REPAINT_ON_RESIZE
	);

	my $original_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Original text:') );
	$self->{original_text} = Wx::TextCtrl->new(
		$self, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxTE_MULTILINE | Wx::wxNO_FULL_REPAINT_ON_RESIZE
	);

	my $matched_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Matched text:') );
	$self->{matched_text} = Wx::TextCtrl->new(
		$self, -1, '', Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxTE_MULTILINE | Wx::wxNO_FULL_REPAINT_ON_RESIZE
	);

	# Modifiers
	my %m = $self->_modifiers();
	foreach my $name ( keys %m ) {
		$self->{$name} = Wx::CheckBox->new(
			$self,
			-1,
			$m{$name}{name},
		);
	}

	my %regex_groups = $self->_regex_groups;
	foreach my $code ( sort keys %regex_groups ) {
		my %sub_group   = %{ $regex_groups{$code} };
		my $button_name = $code . '_button';
		$self->{$button_name} = Wx::Button->new(
			$self, -1, $sub_group{label},
		);

		my $menu_name = $code . '_menu';

		Wx::Event::EVT_BUTTON(
			$self,
			$self->{$button_name},
			sub {
				my @pos  = $self->{$button_name}->GetPositionXY;
				my @size = $self->{$button_name}->GetSizeWH;
				$self->PopupMenu( $self->{$menu_name}, $pos[0], $pos[1] + $size[1] );
			},
		);

		$self->{$menu_name} = Wx::Menu->new;
		my %sub_group_value = %{ $sub_group{value} };
		foreach my $element ( sort keys %sub_group_value ) {
			my $label = $element;
			$label =~ s/^\d{2}//;
			my $menu_item = $self->{$menu_name}->Append( -1, $label . "\t" . $sub_group_value{$element} );

			Wx::Event::EVT_MENU(
				$self,
				$menu_item,
				sub {
					$_[0]->{regex}->WriteText($label);
				},
			);
		}
	}

	# Matching radio button
	$self->{matching} = Wx::RadioButton->new(
		$self, -1, Wx::gettext('Matching'),
	);

	# Substitution radio button
	$self->{substituting} = Wx::RadioButton->new(
		$self, -1, Wx::gettext('Substituting'),
	);

	# Close button
	$self->{close_button} = Wx::Button->new(
		$self, Wx::wxID_CANCEL, Wx::gettext('&Close'),
	);

	# Dialog Layout

	my $modifiers = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$modifiers->AddStretchSpacer;
	$modifiers->Add( $self->{ignore_case}, 0, Wx::wxALL, 1 );
	$modifiers->Add( $self->{single_line}, 0, Wx::wxALL, 1 );
	$modifiers->Add( $self->{multi_line},  0, Wx::wxALL, 1 );
	$modifiers->Add( $self->{extended},    0, Wx::wxALL, 1 );

	my $operation = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$operation->AddStretchSpacer;
	$operation->Add( $self->{matching},     0, Wx::wxALL, 1 );
	$operation->Add( $self->{substituting}, 0, Wx::wxALL, 1 );
	$operation->AddStretchSpacer;

	my $regex = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$regex->Add( $self->{regex}, 1, Wx::wxALL | Wx::wxEXPAND, 1 );

	my $regex_groups = Wx::BoxSizer->new(Wx::wxVERTICAL);
	foreach my $code ( sort keys %regex_groups ) {
		my $button_name = $code . '_button';
		$regex_groups->Add( $self->{$button_name}, 0, Wx::wxEXPAND, 1 );
	}

	my $combined = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$combined->Add( $regex,        2, Wx::wxALL | Wx::wxEXPAND, 0 );
	$combined->Add( $regex_groups, 0, Wx::wxALL | Wx::wxEXPAND, 0 );

	# Vertical layout of the left hand side
	my $left = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$left->Add( $operation, 0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$left->Add( $modifiers, 0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$left->AddSpacer(5);
	$left->Add( $regex_label, 0, Wx::wxALL | Wx::wxEXPAND, 1 );
	$left->Add( $combined,    0, Wx::wxALL | Wx::wxEXPAND, 2 );

	$left->Add( $substitute_label,   0, Wx::wxALL | Wx::wxEXPAND, 1 );
	$left->Add( $self->{substitute}, 1, Wx::wxALL | Wx::wxEXPAND, 1 );

	$left->Add( $original_label,        0, Wx::wxALL | Wx::wxEXPAND, 1 );
	$left->Add( $self->{original_text}, 1, Wx::wxALL | Wx::wxEXPAND, 1 );
	$left->Add( $matched_label,         0, Wx::wxALL | Wx::wxEXPAND, 1 );
	$left->Add( $self->{matched_text},  1, Wx::wxALL | Wx::wxEXPAND, 1 );
	$left->AddSpacer(5);
	$left->Add( $self->{close_button}, 0, Wx::wxALIGN_CENTER_HORIZONTAL, 1 );

	# Main sizer
	$sizer->Add( $left, 1, Wx::wxALL | Wx::wxEXPAND, 5 );
}

sub _bind_events {
	my $self = shift;

	Wx::Event::EVT_TEXT(
		$self,
		$self->{regex},
		sub { $_[0]->run; },
	);
	Wx::Event::EVT_TEXT(
		$self,
		$self->{substitute},
		sub { $_[0]->run; },
	);
	Wx::Event::EVT_TEXT(
		$self,
		$self->{original_text},
		sub { $_[0]->run; },
	);

	# Modifiers
	my %m = $self->_modifiers();
	foreach my $name ( keys %m ) {
		Wx::Event::EVT_CHECKBOX(
			$self,
			$self->{$name},
			sub {
				$_[0]->box_clicked($name);
			},
		);
	}

	Wx::Event::EVT_RADIOBUTTON(
		$self,
		$self->{matching},
		sub { $_[0]->run; },
	);
	Wx::Event::EVT_RADIOBUTTON(
		$self,
		$self->{substituting},
		sub { $_[0]->run; },
	);
}


#
# A private method that returns a hash of regex modifiers
#
sub _modifiers {
	my $self = shift;
	return (
		ignore_case => { mod => 'i', name => sprintf( Wx::gettext('Ignore case (%s)'), 'i' ) },
		single_line => { mod => 's', name => sprintf( Wx::gettext('Single-line (%s)'), 's' ) },
		multi_line  => { mod => 'm', name => sprintf( Wx::gettext('Multi-line (%s)'),  'm' ) },
		extended    => { mod => 'x', name => sprintf( Wx::gettext('Extended (%s)'),    'x' ) },
	);
}


# -- public methods

sub show {
	my $self = shift;

	$self->{regex}->AppendText("regex");
	$self->{substitute}->AppendText("substitute");
	$self->{original_text}->AppendText("Original text");
	$self->{matching}->SetValue(1);

	$self->Show;
}

sub run {
	my $self = shift;

	my $regex = $self->{regex}->GetRange( 0, $self->{regex}->GetLastPosition );
	my $original_text = $self->{original_text}->GetRange( 0, $self->{original_text}->GetLastPosition );
	my $substitute = $self->{substitute}->GetRange( 0, $self->{substitute}->GetLastPosition );


	my $start = '';
	my $end   = '';
	my %m     = $self->_modifiers();
	foreach my $name ( keys %m ) {
		if ( $self->{$name}->IsChecked ) {
			$start .= $m{$name}{mod};
		} else {
			$end .= $m{$name}{mod};
		}
	}
	my $xism = "$start-$end";

	$self->{matched_text}->Clear;

	if ( $self->{matching}->GetValue ) {
		my $match;
		eval {
			if ( $original_text =~ /(?$xism:$regex)/ )
			{
				$match = substr( $original_text, $-[0], $+[0] - $-[0] );
			}
		};
		if ($@) {
			$self->{matched_text}->AppendText("Match failure in $regex:  $@");
			return;
		}

		if ( defined $match ) {
			$self->{matched_text}->AppendText("Matched '$match'");
		} else {
			$self->{matched_text}->AppendText("No match");
		}
	} else {
		$self->{matched_text}->AppendText("Substitute not yet implemented");
	}

	return;
}

sub box_clicked {
	my $self = shift;
	$self->run();
	return;
}

1;

__END__

=pod

=head1 NAME

Padre::Wx::Dialog::RegexEditor - dialog to make it easy to create a regular expression

=head1 DESCRIPTION


The C<Regex Editor> provides an interface to easily create regular
expressions used in Perl.

The user can insert a regular expression (the surrounding C</> characters are not
needed) and a text. The C<Regex Editor> will automatically display the matching
text in the bottom right window.


At the top of the window the user can select any of the four
regular expression modifiers:

=over

=item Ignore case (i)

=item Single-line (s)

=item Multi-line (m)

=item Extended (x)

=back

=head1 TO DO

Implement substitute as well

Global match

Allow the change/replacement of the // around the regular expression

Highlight the match in the source text instead of in
a separate window

Display the captured groups in a tree hierarchy similar to Rx ?

  Group                  Span (character) Value
  Match 0 (Group 0)      4-7              the actual match

Display the various Perl variable containing the relevant values
e.g. the C<@-> and C<@+> arrays, the C<%+> hash
C<$1>, C<$2>...

point out what to use instead of C<$@> and C<$'> and C<$`>

English explanation of the regular expression

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
