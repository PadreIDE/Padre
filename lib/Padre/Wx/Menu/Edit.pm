package Padre::Wx::Menu::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Current  ();
use Padre::Feature  ();
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.94';
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
		'edit.undo',
	);

	$self->{redo} = $self->add_menu_action(
		'edit.redo',
	);

	$self->AppendSeparator;

	# Selection
	my $edit_select = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('&Select'),
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
		'edit.cut',
	);

	$self->{copy} = $self->add_menu_action(
		'edit.copy',
	);

	# Special copy
	my $edit_copy = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Cop&y Specials'),
		$edit_copy
	);

	$self->{copy_filename} = $self->add_menu_action(
		$edit_copy,
		'edit.copy_filename',
	);

	$self->{copy_basename} = $self->add_menu_action(
		$edit_copy,
		'edit.copy_basename',
	);

	$self->{copy_dirname} = $self->add_menu_action(
		$edit_copy,
		'edit.copy_dirname',
	);

	$self->{copy_content} = $self->add_menu_action(
		$edit_copy,
		'edit.copy_content',
	);

	# Paste
	$self->{paste} = $self->add_menu_action(
		'edit.paste',
	);

	my $submenu = Wx::Menu->new;
	$self->{insert_submenu} = $self->AppendSubMenu(
		$submenu,
		Wx::gettext('Insert'),
	);

	$self->{insert_from_file} = $self->add_menu_action(
		$submenu,
		'edit.insert.from_file',
	);

	$self->{snippets} = $self->add_menu_action(
		$submenu,
		'edit.insert.snippets',
	);

	$self->{insert_special} = $self->add_menu_action(
		$submenu,
		'edit.insert.insert_special',
	);

	$self->AppendSeparator;

	$self->{next_problem} = $self->add_menu_action(
		'edit.next_problem',
	);

	$self->{next_difference} = $self->add_menu_action(
		'edit.next_difference',
	) if Padre::Feature::DIFF_DOCUMENT;

	$self->{quick_fix} = $self->add_menu_action(
		'edit.quick_fix',
	) if Padre::Feature::QUICK_FIX;

	$self->{autocomp} = $self->add_menu_action(
		'edit.autocomp',
	);

	$self->{brace_match} = $self->add_menu_action(
		'edit.brace_match',
	);

	$self->{brace_match_select} = $self->add_menu_action(
		'edit.brace_match_select',
	);

	$self->{join_lines} = $self->add_menu_action(
		'edit.join_lines',
	);

	$self->AppendSeparator;

	# Commenting
	$self->{comment_toggle} = $self->add_menu_action(
		'edit.comment_toggle',
	);

	$self->{comment} = $self->add_menu_action(
		'edit.comment',
	);

	$self->{uncomment} = $self->add_menu_action(
		'edit.uncomment',
	);

	$self->AppendSeparator;

	# Conversions and Transforms
	$self->{convert_encoding} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Convert &Encoding'),
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
		Wx::gettext('Convert &Line Endings'),
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
		Wx::gettext('Tabs and S&paces'),
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
		Wx::gettext('Upper/Lo&wer Case'),
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

	# Add Patch/Diff
	$self->{patch_diff} = $self->add_menu_action(
		'edit.patch_diff',
	);

	$self->{filter_tool} = $self->add_menu_action(
		'edit.filter_tool',
	);

	$self->{perl_filter} = $self->add_menu_action(
		'edit.perl_filter',
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
	my $current  = Padre::Current::_CURRENT(@_);
	my $editor   = $current->editor || 0;
	my $document = $current->document;
	my $hasdoc   = $document ? 1 : 0;
	my $comment  = $hasdoc ? ( $document->get_comment_line_string ? 1 : 0 ) : 0;
	my $newline  = $hasdoc ? $document->newline_type : '';
	my $quickfix = $hasdoc && $document->can('get_quick_fix_provider');

	# Handle the simple cases
	$self->{next_problem}->Enable($hasdoc);
	$self->{next_difference}->Enable($hasdoc) if defined $self->{next_difference};
	if (Padre::Feature::QUICK_FIX) {
		$self->{quick_fix}->Enable($quickfix);
	}
	$self->{autocomp}->Enable($hasdoc);
	$self->{brace_match}->Enable($hasdoc);
	$self->{brace_match_select}->Enable($hasdoc);
	$self->{join_lines}->Enable($hasdoc);
	$self->{insert_special}->Enable($hasdoc);
	$self->{snippets}->Enable($hasdoc);
	$self->{comment_toggle}->Enable($comment);
	$self->{comment}->Enable($comment);
	$self->{uncomment}->Enable($comment);
	$self->{convert_encoding_system}->Enable($hasdoc);
	$self->{convert_encoding_utf8}->Enable($hasdoc);
	$self->{convert_encoding_to}->Enable($hasdoc);

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
	$self->{patch_diff}->Enable($hasdoc);

	# Handle the complex cases
	$self->{undo}->Enable($editor);
	$self->{redo}->Enable($editor);
	$self->{paste}->Enable($editor);

	# Copy specials
	$self->{copy_filename}->Enable($hasdoc);
	$self->{copy_basename}->Enable($hasdoc);
	$self->{copy_dirname}->Enable($hasdoc);
	$self->{copy_content}->Enable($hasdoc);

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
