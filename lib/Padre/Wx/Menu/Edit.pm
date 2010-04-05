package Padre::Wx::Menu::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.59';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Undo/Redo
	$self->{undo} = $self->add_menu_action(
		$self,
		'edit.undo',
	);

	$self->{redo} = $self->add_menu_action(
		$self,
		'edit.redo',
	);

	$self->AppendSeparator;

	# Selection
	my $edit_select = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Select"),
		$edit_select
	);

	$self->add_menu_action(
		$edit_select,
		'edit.select_all',
	);

	$edit_select->AppendSeparator;

	$self->add_menu_action(
		$edit_select,
		'edit.mark_selection_start',
	);

	$self->add_menu_action(
		$edit_select,
		'edit.mark_selection_end',
	);

	$self->add_menu_action(
		$edit_select,
		'edit.clear_selection_marks',
	);

	# Cut and Paste
	$self->{cut} = $self->add_menu_action(
		$self,
		'edit.cut',
	);

	$self->{copy} = $self->add_menu_action(
		$self,
		'edit.copy',
	);

	# Special copy
	my $edit_copy = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Copy specials"),
		$edit_copy
	);

	$self->add_menu_action(
		$edit_copy,
		'edit.copy_filename',
	);

	$self->add_menu_action(
		$edit_copy,
		'edit.copy_basename',
	);

	$self->add_menu_action(
		$edit_copy,
		'edit.copy_dirname',
	);

	$self->add_menu_action(
		$edit_copy,
		'edit.copy_content',
	);

	# Paste
	$self->{paste} = $self->add_menu_action(
		$self,
		'edit.paste',
	);

	my $submenu = Wx::Menu->new;
	$self->{insert_submenu} = $self->AppendSubMenu( $submenu, Wx::gettext('Insert') );

	$self->{insert_special} = $self->add_menu_action(
		$submenu,
		'edit.insert.insert_special',
	);

	$self->{snippets} = $self->add_menu_action(
		$submenu,
		'edit.insert.snippets',
	);

	$self->{insert_from_file} = $self->add_menu_action(
		$submenu,
		'edit.insert.from_file',
	);

	$self->AppendSeparator;

	# Miscellaneous Actions
	$self->{goto} = $self->add_menu_action(
		$self,
		'edit.goto',
	);

	$self->{next_problem} = $self->add_menu_action(
		$self,
		'edit.next_problem',
	);

	$self->{quick_fix} = $self->add_menu_action(
		$self,
		'edit.quick_fix',
	);

	$self->{autocomp} = $self->add_menu_action(
		$self,
		'edit.autocomp',
	);

	$self->{brace_match} = $self->add_menu_action(
		$self,
		'edit.brace_match',
	);

	$self->{brace_match_select} = $self->add_menu_action(
		$self,
		'edit.brace_match_select',
	);

	$self->{join_lines} = $self->add_menu_action(
		$self,
		'edit.join_lines',
	);

	$self->AppendSeparator;

	# Commenting
	$self->{comment_toggle} = $self->add_menu_action(
		$self,
		'edit.comment_toggle',
	);

	$self->{comment} = $self->add_menu_action(
		$self,
		'edit.comment',
	);

	$self->{uncomment} = $self->add_menu_action(
		$self,
		'edit.uncomment',
	);

	$self->AppendSeparator;

	# Conversions and Transforms
	$self->{convert_encoding} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Convert Encoding"),
		$self->{convert_encoding}
	);

	$self->{convert_encoding_system} = $self->add_menu_action(
		$self->{convert_encoding},
		'edit.convert_encoding_system',
	);

	$self->{convert_encoding_utf8} = $self->add_menu_action(
		$self->{convert_encoding},
		'edit.convert_encoding_utf8',
	);

	$self->{convert_encoding_to} = $self->add_menu_action(
		$self->{convert_encoding},
		'edit.convert_encoding_to',
	);

	$self->{convert_nl} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Convert EOL"),
		$self->{convert_nl}
	);

	$self->{convert_nl_windows} = $self->add_menu_action(
		$self->{convert_nl},
		'edit.convert_nl_windows',
	);

	$self->{convert_nl_unix} = $self->add_menu_action(
		$self->{convert_nl},
		'edit.convert_nl_unix',
	);

	$self->{convert_nl_mac} = $self->add_menu_action(
		$self->{convert_nl},
		'edit.convert_nl_mac',
	);

	# Tabs And Spaces
	$self->{tabs} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Tabs and Spaces"),
		$self->{tabs},
	);

	$self->{tabs_to_spaces} = $self->add_menu_action(
		$self->{tabs},
		'edit.tabs_to_spaces',
	);

	$self->{spaces_to_tabs} = $self->add_menu_action(
		$self->{tabs},
		'edit.spaces_to_tabs',
	);

	$self->{tabs}->AppendSeparator;

	$self->{delete_trailing} = $self->add_menu_action(
		$self->{tabs},
		'edit.delete_trailing',
	);

	$self->{delete_leading} = $self->add_menu_action(
		$self->{tabs},
		'edit.delete_leading',
	);

	# Upper and Lower Case
	$self->{case} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Upper/Lower Case"),
		$self->{case},
	);

	$self->{case_upper} = $self->add_menu_action(
		$self->{case},
		'edit.case_upper',
	);

	$self->{case_lower} = $self->add_menu_action(
		$self->{case},
		'edit.case_lower',
	);

	$self->AppendSeparator;

	# Diff tools
	$self->{diff} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Diff Tools"),
		$self->{diff},
	);

	$self->{diff2saved} = $self->add_menu_action(
		$self->{diff},
		'edit.diff2saved',
	);
	$self->{diff}->AppendSeparator;
	$self->{applydiff2file} = $self->add_menu_action(
		$self->{diff},
		'edit.applydiff2file',
	);
	$self->{applydiff2project} = $self->add_menu_action(
		$self->{diff},
		'edit.applydiff2project',
	);

	# End diff tools


	$self->{filter_tool} = $self->add_menu_action(
		$self,
		'edit.filter_tool',
	);

	$self->AppendSeparator;

	$self->{show_as_number} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Show as'),
		$self->{show_as_number}
	);

	$self->{show_as_hex} = $self->add_menu_action(
		$self->{show_as_number},
		'edit.show_as_hex',
	);

	$self->{show_as_decimal} = $self->add_menu_action(
		$self->{show_as_number},
		'edit.show_as_decimal',
	);

	return $self;
}

sub title {
	Wx::gettext('&Edit');
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $editor   = $current->editor || 0;
	my $text     = $current->text;
	my $document = $current->document;
	my $hasdoc   = $document ? 1 : 0;
	my $newline  = $hasdoc ? $document->newline_type : '';

	# Handle the simple cases
	$self->{goto}->Enable($hasdoc);
	$self->{next_problem}->Enable($hasdoc);
	$self->{quick_fix}->Enable($hasdoc);
	$self->{autocomp}->Enable($hasdoc);
	$self->{brace_match}->Enable($hasdoc);
	$self->{brace_match_select}->Enable($hasdoc);
	$self->{join_lines}->Enable($hasdoc);

	$self->{insert_special}->Enable($hasdoc);
	$self->{snippets}->Enable($hasdoc);
	$self->{comment_toggle}->Enable($hasdoc);
	$self->{comment}->Enable($hasdoc);
	$self->{uncomment}->Enable($hasdoc);
	$self->{convert_encoding_system}->Enable($hasdoc);
	$self->{convert_encoding_utf8}->Enable($hasdoc);
	$self->{convert_encoding_to}->Enable($hasdoc);
	$self->{diff2saved}->Enable($hasdoc);
	$self->{applydiff2file}->Enable(0);
	$self->{applydiff2project}->Enable(0);
	$self->{insert_from_file}->Enable($hasdoc);
	$self->{case_upper}->Enable($hasdoc);
	$self->{case_lower}->Enable($hasdoc);

	unless ( $newline eq 'WIN' ) {
		$self->{convert_nl_windows}->Enable($hasdoc);
	}
	unless ( $newline eq 'UNIX' ) {
		$self->{convert_nl_unix}->Enable($hasdoc);
	}
	unless ( $newline eq 'MAC' ) {
		$self->{convert_nl_mac}->Enable($hasdoc);
	}
	$self->{tabs_to_spaces}->Enable($hasdoc);
	$self->{spaces_to_tabs}->Enable($hasdoc);
	$self->{delete_leading}->Enable($hasdoc);
	$self->{delete_trailing}->Enable($hasdoc);
	$self->{show_as_hex}->Enable($hasdoc);
	$self->{show_as_decimal}->Enable($hasdoc);

	# Handle the complex cases
	my $selection = !!( defined $text and $text ne '' );
	$self->{undo}->Enable($editor);
	$self->{redo}->Enable($editor);
	$self->{paste}->Enable($editor);

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
