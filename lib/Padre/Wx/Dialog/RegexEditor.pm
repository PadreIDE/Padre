package Padre::Wx::Dialog::RegexEditor;

# The Regex Editor for Padre

use 5.008;
use strict;
use warnings;
use Padre::Wx 'RichText';
use Padre::Wx::Icon       ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Main
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
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_FRAME_STYLE,
	);

	# Set basic dialog properties
	$self->SetIcon(Padre::Wx::Icon::PADRE);
	$self->SetMinSize( [ 380, 500 ] );

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$self->{sizer} = $sizer;

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
			label => Wx::gettext('Character classes'),
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
			label => Wx::gettext('&POSIX Character classes'),
			value => {
				'00[:alpha:]'  => Wx::gettext('Alphabetic characters'),
				'01[:alnum:]'  => Wx::gettext('Alphanumeric characters'),
				'02[:ascii:]'  => Wx::gettext('7-bit US-ASCII character'),
				'03[:blank:]'  => Wx::gettext('Space and tab'),
				'04[:cntrl:]'  => Wx::gettext('Control characters'),
				'05[:digit:]'  => Wx::gettext('Digits'),
				'06[:graph:]'  => Wx::gettext('Visible characters'),
				'07[:lower:]'  => Wx::gettext('Lowercase characters'),
				'08[:print:]'  => Wx::gettext('Visible characters and spaces'),
				'09[:punct:]'  => Wx::gettext('Punctuation characters'),
				'10[:space:]'  => Wx::gettext('Whitespace characters'),
				'11[:upper:]'  => Wx::gettext('Uppercase characters'),
				'12[:word:]'   => Wx::gettext('Alphanumeric characters plus "_"'),
				'13[:xdigit:]' => Wx::gettext('Hexadecimal digits'),
			}
		},
		'02' => {
			label => Wx::gettext('&Quantifiers'),
			value => {
				'00*'     => Wx::gettext('Match 0 or more times'),
				'01+'     => Wx::gettext('Match 1 or more times'),
				'02?'     => Wx::gettext('Match 1 or 0 times'),
				'03{m}'   => Wx::gettext('Match exactly m times'),
				'05{n,}'  => Wx::gettext('Match at least n times'),
				'05{m,n}' => Wx::gettext('Match at least m but not more than n times'),
			}
		},
		'03' => {
			label => Wx::gettext('Miscellaneous'),
			value => {
				'00|'     => Wx::gettext('Alternation'),
				'01[ ]'   => Wx::gettext('Character set'),
				'02^'     => Wx::gettext('Beginning of line'),
				'03$'     => Wx::gettext('End of line'),
				'04\b'    => Wx::gettext('A word boundary'),
				'05\B'    => Wx::gettext('Not a word boundary'),
				'06(?# )' => Wx::gettext('A comment'),
			}
		},
		'04' => {
			label => Wx::gettext('Grouping constructs'),
			value => {
				'00( )'    => Wx::gettext('A group'),
				'01(?: )'  => Wx::gettext('Non-capturing group'),
				'02(?= )'  => Wx::gettext('Positive lookahead assertion'),
				'03(?! )'  => Wx::gettext('Negative lookahead assertion'),
				'04(?<=)'  => Wx::gettext('Positive lookbehind assertion'),
				'05(?<! )' => Wx::gettext('Negative lookbehind assertion'),
				'06\n'     => Wx::gettext('Backreference to the nth group'),
			}
		},

		# next list taken from perldoc perlre
		# most of these are not interesting for beginners so I am not sure we need to show them
		'05' => {
			label => Wx::gettext('Escape characters'),
			value => {
				'00\t'       => Wx::gettext('Tab'),
				'01\n'       => Wx::gettext('Newline'),
				'02\r'       => Wx::gettext('Return'),
				'03\f'       => Wx::gettext('Form feed'),
				'04\a'       => Wx::gettext('Alarm'),
				'05\e'       => Wx::gettext('Escape (Esc)'),
				'06\033'     => Wx::gettext('Octal character'),
				'07\x1B'     => Wx::gettext('Hex character'),
				'08\x{263a}' => Wx::gettext('Long hex character'),
				'09\cK'      => Wx::gettext('Control character'),
				'10\N{name}' => Wx::gettext("Unicode character 'name'"),
				'11\l'       => Wx::gettext('Lowercase next character'),
				'12\u'       => Wx::gettext('Uppercase next character'),
				'13\L'       => Wx::gettext('Lowercase till \E'),
				'14\U'       => Wx::gettext('Uppercase till \E'),
				'15\E'       => Wx::gettext('End case modification/metacharacter quoting'),
				'16\Q'       => Wx::gettext('Quote (disable) pattern metacharacters till \E'),
			}
		},
	);
}

sub _create_controls {
	my ( $self, $sizer ) = @_;

	# Dialog Controls, created in keyboard navigation order

	# Regex text field
	my $regex_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Regular expression:') );
	$self->{regex} = Wx::TextCtrl->new(
		$self, -1, '', Wx::DefaultPosition, Wx::DefaultSize,
		Wx::RE_MULTILINE | Wx::WANTS_CHARS # Otherwise arrows will not work on win32
	);

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
			my $menu_item = $self->{$menu_name}->Append( -1, $label . '  ' . $sub_group_value{$element} );

			Wx::Event::EVT_MENU(
				$self,
				$menu_item,
				sub {
					$_[0]->{regex}->WriteText($label);
				},
			);
		}
	}

	# Optionally toggle the visibility of the description field
	$self->{description_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext('Show &Description'),
	);

	# Describe-the-regex text field
	$self->{description_text} = Wx::TextCtrl->new(
		$self, -1, '', Wx::DefaultPosition, Wx::DefaultSize,
		Wx::TE_MULTILINE | Wx::NO_FULL_REPAINT_ON_RESIZE
	);

	# Description is hidden by default
	$self->{description_text}->Hide;

	# Original input text field
	my $original_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Original text:') );
	$self->{original_text} = Wx::TextCtrl->new(
		$self, -1, '', Wx::DefaultPosition, Wx::DefaultSize,
		Wx::TE_MULTILINE | Wx::NO_FULL_REPAINT_ON_RESIZE
	);

	# Matched readonly text field
	my $matched_label = Wx::StaticText->new( $self, -1, Wx::gettext('Matched text:') );
	$self->{matched_text} = Wx::RichTextCtrl->new(
		$self, -1, '', Wx::DefaultPosition, Wx::DefaultSize,
		Wx::RE_MULTILINE | Wx::RE_READONLY | Wx::WANTS_CHARS # Otherwise arrows will not work on win32
	);

	# Toggle the visibility of the replace (substitution) fields
	$self->{replace_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext('Show Subs&titution'),
	);

	# Replace regex text field
	$self->{replace_label} = Wx::StaticText->new( $self, -1, Wx::gettext('&Replace text with:') );
	$self->{replace_text} = Wx::TextCtrl->new(
		$self, -1, '', Wx::DefaultPosition, Wx::DefaultSize,
		Wx::TE_MULTILINE | Wx::NO_FULL_REPAINT_ON_RESIZE
	);

	$self->{replace_label}->Hide;
	$self->{replace_text}->Hide;

	# Result from replace text field
	$self->{result_label} = Wx::StaticText->new( $self, -1, Wx::gettext('&Result from replace:') );
	$self->{result_text} = Wx::RichTextCtrl->new(
		$self, -1, '', Wx::DefaultPosition, Wx::DefaultSize,
		Wx::RE_MULTILINE | Wx::RE_READONLY | Wx::WANTS_CHARS # otherwise arrows will not work on win32
	);

	$self->{result_label}->Hide;
	$self->{result_text}->Hide;

	# Insert regex into current document
	$self->{insert_button} = Wx::Button->new(
		$self, -1, Wx::gettext('Insert'),
	);

	# Close button
	$self->{close_button} = Wx::Button->new(
		$self, Wx::ID_CANCEL, Wx::gettext('&Close'),
	);

	my $buttons = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$buttons->AddStretchSpacer;
	$buttons->Add( $self->{insert_button}, 0, Wx::ALL, 1 );
	$buttons->Add( $self->{close_button},  0, Wx::ALL, 1 );
	$buttons->AddStretchSpacer;

	# Modifiers
	my %m = $self->_modifiers;
	foreach my $name ( $self->_modifier_keys ) {
		$self->{$name} = Wx::CheckBox->new(
			$self,
			-1,
			$m{$name}{name},
		);

		$self->{$name}->SetToolTip( Wx::ToolTip->new( $m{$name}{tooltip} ) );
	}

	# Dialog Layout

	my $modifiers = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$modifiers->AddStretchSpacer;
	$modifiers->Add( $self->{ignore_case}, 0, Wx::ALL, 1 );
	$modifiers->Add( $self->{single_line}, 0, Wx::ALL, 1 );
	$modifiers->Add( $self->{multi_line},  0, Wx::ALL, 1 );
	$modifiers->Add( $self->{extended},    0, Wx::ALL, 1 );
	$modifiers->Add( $self->{global},      0, Wx::ALL, 1 );

	$modifiers->AddStretchSpacer;

	my $regex = Wx::BoxSizer->new(Wx::VERTICAL);
	$regex->Add( $self->{regex}, 1, Wx::ALL | Wx::EXPAND, 1 );

	my $regex_groups = Wx::BoxSizer->new(Wx::VERTICAL);
	foreach my $code ( sort keys %regex_groups ) {
		my $button_name = $code . '_button';
		$regex_groups->Add( $self->{$button_name}, 0, Wx::EXPAND, 1 );
	}

	my $combined = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$combined->Add( $regex,        2, Wx::ALL | Wx::EXPAND, 0 );
	$combined->Add( $regex_groups, 0, Wx::ALL | Wx::EXPAND, 0 );

	# Vertical layout of the left hand side
	my $left = Wx::BoxSizer->new(Wx::VERTICAL);
	$left->Add( $modifiers, 0, Wx::ALL | Wx::EXPAND, 2 );
	$left->AddSpacer(5);
	$left->Add( $regex_label, 0, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $combined,    0, Wx::ALL | Wx::EXPAND, 2 );

	$left->Add( $self->{description_checkbox}, 0, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $self->{description_text},     2, Wx::ALL | Wx::EXPAND, 1 );

	$left->Add( $original_label,        0, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $self->{original_text}, 1, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $matched_label,         0, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $self->{matched_text},  1, Wx::ALL | Wx::EXPAND, 1 );

	$left->Add( $self->{replace_checkbox}, 0, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $self->{replace_label},    0, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $self->{replace_text},     1, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $self->{result_label},     0, Wx::ALL | Wx::EXPAND, 1 );
	$left->Add( $self->{result_text},      1, Wx::ALL | Wx::EXPAND, 1 );

	$left->AddSpacer(5);
	$left->Add( $buttons, 0, Wx::ALL | Wx::EXPAND, 1 );

	# Main sizer
	$sizer->Add( $left, 1, Wx::ALL | Wx::EXPAND, 5 );
}

sub _bind_events {
	my $self = shift;

	Wx::Event::EVT_TEXT(
		$self,
		$self->{regex},
		sub { $_[0]->run; },
	);
	Wx::Event::EVT_KEY_DOWN(
		$self,
		sub {
			my ($key_event) = $_[1];
			$self->Hide if $key_event->GetKeyCode == Wx::K_ESCAPE;
			return;
		}
	);
	Wx::Event::EVT_TEXT(
		$self,
		$self->{replace_text},
		sub { $_[0]->run; },
	);
	Wx::Event::EVT_TEXT(
		$self,
		$self->{original_text},
		sub { $_[0]->run; },
	);

	# Modifiers
	foreach my $name ( $self->_modifier_keys ) {
		Wx::Event::EVT_CHECKBOX(
			$self,
			$self->{$name},
			sub {
				$_[0]->box_clicked($name);
			},
		);
	}

	# Description checkbox
	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{description_checkbox},
		sub {

			# toggles the visibility of the description field
			if ( $self->{description_checkbox}->IsChecked ) {
				my $regex = $self->{regex}->GetValue;
				$self->{description_text}->SetValue( $self->_dump_regex($regex) );
			}
			$self->{description_text}->Show( $self->{description_checkbox}->IsChecked );
			$self->{sizer}->Layout;
		},
	);

	# Replace checkbox
	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{replace_checkbox},
		sub {

			$self->replace;

			# toggles the visibility of the replace fields
			foreach my $field (qw(replace_label replace_text result_label result_text)) {
				$self->{$field}->Show( $self->{replace_checkbox}->IsChecked );
			}
			$self->{sizer}->Layout;
		},
	);

	Wx::Event::EVT_KEY_DOWN(
		$self->{matched_text},
		sub {
			my ($key_event) = $_[1];
			$self->Hide if $key_event->GetKeyCode == Wx::K_ESCAPE;
			return;
		}
	);

	Wx::Event::EVT_KEY_DOWN(
		$self->{result_text},
		sub {
			my ($key_event) = $_[1];
			$self->Hide if $key_event->GetKeyCode == Wx::K_ESCAPE;
			return;
		}
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{insert_button},
		sub { shift->_insert_regex; },
	);
}

#
# A private method that inserts the current regex into the current document
#
sub _insert_regex {
	my $self = shift;

	my $match_part   = $self->{regex}->GetValue;
	my $replace_part = $self->{replace_text}->GetValue;

	my ($modifiers) = $self->_get_modifier_settings;

	my $editor = $self->current->editor or return;
	if ( $self->{replace_checkbox}->IsChecked ) {
		$editor->InsertText( $editor->GetCurrentPos, "s/$match_part/$replace_part/$modifiers" );
	} else {
		$editor->InsertText( $editor->GetCurrentPos, "m/$match_part/$modifiers" );
	}

	return;
}


#
# A private method that returns a hash of regex modifiers
#
sub _modifiers {
	return (
		ignore_case => {
			mod     => 'i', name => Wx::gettext('Ignore case (&i)'),
			tooltip => Wx::gettext('Case-insensitive matching')
		},
		single_line => {
			mod     => 's', name => Wx::gettext('Single-line (&s)'),
			tooltip => Wx::gettext('"." also matches newline')
		},
		multi_line => {
			mod => 'm', name => Wx::gettext('Multi-line (&m)'),
			tooltip => Wx::gettext('"^" and "$" match the start and end of any line inside the string')
		},
		extended => {
			mod => 'x', name => Wx::gettext('Extended (&x)'),
			tooltip =>
				Wx::gettext('Extended regular expressions allow free formatting (whitespace is ignored) and comments')
		},
		global => {
			mod     => 'g', name => Wx::gettext('Global (&g)'),
			tooltip => Wx::gettext('Replace all occurrences of the pattern')
		},
	);
}

#
# returns the regex modifier keys in the order they appear in the GUI
#
sub _modifier_keys {
	return qw{ ignore_case single_line multi_line extended	global};
}

# -- public methods

sub show {
	my $self = shift;

	if ( $self->IsShown ) {
		$self->SetFocus;
	} else {
		my $editor = $self->current->editor;
		if ($editor) {
			my $selection        = $editor->GetSelectedText;
			my $selection_length = length $selection;
			if ( $selection_length > 0 ) {
				$self->{regex}->ChangeValue($selection);
			} else {
				$self->{regex}->ChangeValue('\w+');
			}
		} else {
			$self->{regex}->ChangeValue('\w+');
		}

		$self->{replace_text}->ChangeValue('Baz');
		$self->{original_text}->SetValue('Foo Bar');

		$self->Show;
	}

	$self->{regex}->SetFocus;

	return;
}

#
# Private method to dump the regular expression description as text
#
sub _dump_regex {
	if ( scalar @_ == 2 ) {
		my ( $self, $regex ) = @_;
		require PPIx::Regexp;
		return $self->_dump_regex( PPIx::Regexp->new("/$regex/"), '', 0 );
	}

	my ( $self, $parent, $str, $level ) = @_;

	$str   = '' unless $str;
	$level = 0  unless $level;
	my @children = $parent->isa('PPIx::Regexp::Node') ? $parent->children : ();
	foreach my $child (@children) {
		next if $child->content eq '';
		my $class_name = $child->class;
		$class_name =~ s/PPIx::Regexp:://;
		$str .= ( ' ' x ( $level * 4 ) ) . $class_name . '     (' . $child->content . ")\n";
		$str = $self->_dump_regex( $child, $str, $level + 1 );
	}
	return $str;
}

#
# Private method to return all the parsed regex elements as an array
#
sub _parse_regex_elements {
	my ( $parent, $position, @array ) = @_;
	$position = 0  unless $position;
	@array    = () unless @array;
	my @elements = $parent->isa('PPIx::Regexp::Node') ? $parent->elements : ();
	foreach my $element (@elements) {
		my $content = $element->content;
		next if $content eq '';
		my $class_name = $element->class;
		push @array,
			{
			element => $element,
			offset  => $position,
			len     => length $content
			};
		@array = _parse_regex_elements( $element, $position, @array );
		$position += length $content;
	}
	return @array;
}

#
# Returns the user input data of the dialog as a hashref
#
sub get_data {
	my $self = shift;

	my %data = (
		text => {
			regex         => $self->{regex}->GetValue,
			replace       => $self->{replace_text}->GetValue,
			original_text => $self->{original_text}->GetValue,
		},
		modifiers => [ $self->_get_modifier_settings ],
	);

	return \%data;
}

#
# Sets the user input data of the dialog given a hashref containing the results of get_data
#
sub set_data {
	my ( $self, $data_ref ) = @_;

	foreach my $text_field ( keys %{ $data_ref->{text} } ) {
		$self->{$text_field}->SetValue( $data_ref->{text}->{$text_field} );
	}

	my $modifier_string = $data_ref->{modifiers}->[0];
	my %modifiers       = $self->_modifiers;
	foreach my $name ( keys %modifiers ) {
		$self->{$name}->SetValue(1) if $modifier_string =~ s/$modifiers{$name}{mod}//;
	}

	return;
}

#
# Private method to get the modifier settings as two strings
# the first strings returns the active modifiers, the second the
# inactive ones
#
sub _get_modifier_settings {
	my $self = shift;

	my $active_modifiers   = '';
	my $inactive_modifiers = '';
	my %modifiers          = $self->_modifiers;
	foreach my $name ( keys %modifiers ) {
		if ( $self->{$name}->IsChecked ) {
			$active_modifiers .= $modifiers{$name}{mod};
		} else {
			$inactive_modifiers .= $modifiers{$name}{mod};
		}
	}

	return ( $active_modifiers, $inactive_modifiers );
}

sub run {
	my $self = shift;

	my $regex         = $self->{regex}->GetValue;
	my $original_text = $self->{original_text}->GetValue;

	# TODO what about white space only regexes?
	if ( $regex eq '' ) {
		$self->{matched_text}->BeginTextColour(Wx::RED);
		$self->{matched_text}->SetValue( Wx::gettext('Empty regex') );
		$self->{matched_text}->EndTextColour;
		return;
	}

	my ( $active, $inactive ) = $self->_get_modifier_settings;

	$self->{matched_text}->Clear;

	$self->{matched_text}->BeginTextColour(Wx::BLACK);

	my $match;
	my $match_start;
	my $match_end;
	my $result;

	my $warning;

	# Ignore warnings on win32. It's ugly but it works :)
	local $SIG{__WARN__} = sub { $warning = $_[0] };

	# TODO loop on all matches in case of /g
	my $code = "\$result = \$original_text =~ /\$regex/$active; (\$match_start, \$match_end) = (\$-[0], \$+[0])";
	eval $code;
	if ($@) {
		$self->{matched_text}->BeginTextColour(Wx::RED);
		$self->{matched_text}->SetValue( sprintf( Wx::gettext('Match failure in %s:  %s'), $regex, $@ ) );
		$self->{matched_text}->EndTextColour;
		return;
	}

	if ($result) {
		$match = substr( $original_text, $match_start, $match_end - $match_start );
	}

	if ($warning) {
		$self->{matched_text}->BeginTextColour(Wx::RED);
		$self->{matched_text}->SetValue( sprintf( Wx::gettext('Match warning in %s:  %s'), $regex, $warning ) );
		$self->{matched_text}->EndTextColour;
		return;
	}

	if ( defined $match ) {
		if ( $match_start == $match_end ) {
			$self->{matched_text}->BeginTextColour(Wx::RED);
			$self->{matched_text}
				->SetValue( sprintf( Wx::gettext('Match with 0 width at character %s'), $match_start ) );
			$self->{matched_text}->EndTextColour;
		} else {
			my @chars = split( //, $original_text );
			my $pos = 0;
			foreach my $char (@chars) {
				if ( $pos == $match_start ) {
					$self->{matched_text}->BeginTextColour(Wx::BLUE);
					$self->{matched_text}->BeginUnderline;
				} elsif ( $pos == $match_end ) {
					$self->{matched_text}->EndTextColour;
					$self->{matched_text}->EndUnderline;
				}
				$self->{matched_text}->AppendText($char);
				$pos++;
			}
		}
	} else {
		$self->{matched_text}->BeginTextColour(Wx::RED);
		$self->{matched_text}->SetValue( Wx::gettext('No match') );
		$self->{matched_text}->EndTextColour;
	}
	$self->{matched_text}->EndTextColour;

	$self->replace;

	$self->{description_text}->SetValue( $self->_dump_regex($regex) ) if $self->{description_text}->IsShown;

	#	$self->{regex}->Clear;
	#	my @elements = _parse_regex_elements;
	#	foreach my $element (@elements) {
	#		my $class_name = $element->element->class;
	#		if ($class_name eq 'PPIx::Regexp::Token::CharClass::Simple') {
	#			$self->{regex}->BeginTextColour(Wx::RED);
	#		} elsif( $class_name eq 'PPIx::Regexp::Token::Quantifier') {
	#			$self->{regex}->BeginTextColour(Wx::BLUE);
	#		} elsif( $class_name eq 'PPIx::Regexp::Token::Operator') {
	#			$self->{regex}->BeginTextColour(Wx::LIGHT_GREY);
	#		} elsif( $class_name eq 'PPIx::Regexp::Structure::Capture') {
	#			$self->{regex}->BeginTextColour(Wx::CYAN);
	#		}
	#		$self->{regex}->AppendText($element->content);
	#	$self->{regex}->EndTextColour;
	#	}

	return;
}

sub replace {
	my $self = shift;
	return if !$self->{replace_checkbox}->IsChecked;

	my $regex       = $self->{regex}->GetValue;
	my $result_text = $self->{original_text}->GetValue;
	my $replace     = $self->{replace_text}->GetValue;

	my ( $active, $inactive ) = $self->_get_modifier_settings;

	$self->{result_text}->Clear;

	my $code = "\$result_text =~ s{\$regex}{$replace}$active";
	eval $code;
	if ($@) {
		$self->{result_text}->BeginTextColour(Wx::RED);
		$self->{result_text}->AppendText( sprintf( Wx::gettext('Replace failure in %s:  %s'), $regex, $@ ) );
		$self->{result_text}->EndTextColour;
		return;
	}

	if ( defined $result_text ) {
		$self->{result_text}->SetValue($result_text);
	}

	return;
}

sub box_clicked {
	my $self = shift;
	$self->run;
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

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut
