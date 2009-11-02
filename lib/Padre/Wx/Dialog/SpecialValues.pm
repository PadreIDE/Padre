package Padre::Wx::Dialog::SpecialValues;

# Insert special values such as dates in your code

use 5.008;
use strict;
use warnings;
use Padre::Wx         ();
use Padre::Wx::Dialog ();
use Padre::Current    ();

our $VERSION = '0.49';

my $categories = {
	'Dates' => [
		{ label => 'Now',       action => _get_date_info('now') },
		{ label => 'Yesterday', action => _get_date_info('epoch') },
		{ label => 'Tomorrow',  action => _get_date_info('epoch') },
	],
	'File' => [
		{ label => 'Size', action => _get_file_info('size') },
		{ label => 'Name', action => _get_file_info('name') },
	],
	'Line' => [
		{ label => 'Number', action => _get_line_info('number') },
	],
};

my $cats_list = [ sort keys %$categories ];

sub get_layout {
	my ($config) = @_;

	my $default_cat_values = [ map ( $_->{label}, @{ $categories->{ $cats_list->[0] } } ) ];

	my @layout = (
		[ [ 'Wx::StaticText', undef, Wx::gettext('Class:') ], [ 'Wx::Choice', '_find_cat_', $cats_list ], ],
		[   [ 'Wx::StaticText', undef,                 Wx::gettext('Special Value:') ],
			[ 'Wx::Choice',     '_find_specialvalue_', $default_cat_values ],
		],
		[ [], [ 'Wx::Button', '_insert_', Wx::gettext('&Insert') ], [ 'Wx::Button', '_cancel_', Wx::wxID_CANCEL ], ],
	);
	return \@layout;
}

sub dialog {
	my $class  = shift;
	my $parent = shift;
	my $args   = shift;
	my $config = Padre->ide->config;
	my $layout = get_layout($config);
	my $dialog = Padre::Wx::Dialog->new(
		parent => $parent,
		title  => Wx::gettext("Insert Special Values"),
		layout => $layout,
		width  => [ 150, 200 ],
	);

	Wx::Event::EVT_CHOICE( $dialog, $dialog->{_widgets_}->{_find_cat_}, \&find_category );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_insert_}, \&get_value );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_cancel_}, \&cancel_clicked );

	$dialog->{_widgets_}->{_find_cat_}->SetFocus;
	$dialog->{_widgets_}->{_insert_}->SetDefault;

	return $dialog;
}

sub insert_special {
	my $class = shift;
	my $main  = shift;
	return if not Padre::Current->editor;
	my $dialog = $class->dialog( $main, {} );
	$dialog->Show(1);
	return;
}

sub find_category {
	my $dialog   = shift;
	my $cat_name = _get_cat_name($dialog);
	my $values   = [ map ( $_->{label}, @{ $categories->{$cat_name} } ) ];
	my $field    = $dialog->{_widgets_}->{_find_specialvalue_};
	$field->Clear;
	$field->AppendItems($values);
	$field->SetSelection(0);
	return;
}

sub get_value {
	my $dialog    = shift;
	my $data      = $dialog->get_data or return;
	my $cat_name  = _get_cat_name($dialog);
	my $value_ind = $data->{_find_specialvalue_};
	my $text      = &{ $categories->{$cat_name}[$value_ind]{action} };
	warn "cat : $cat_name, value $value_ind, text : $text\n";

	my $editor = Padre::Current->editor;
	$editor->ReplaceSelection('');
	my $pos = $editor->GetCurrentPos;
	$editor->InsertText( $pos, $text );
	return;
}

sub cancel_clicked {
	$_[0]->Destroy;
	return;
}


######

sub _get_cat_name {
	my $dialog = shift;
	my $data   = $dialog->get_data;

	#    warn Dumper (data => $data);
	my $cat_name = $cats_list->[ $data->{_find_cat_} ];
	return $cat_name;
}

sub _get_date_info {
	my $type = shift;
	if ( $type eq 'now' ) {
		return sub {
			return scalar localtime;
			}
	} else {
		return sub {
			warn "date info $type not implemented yet\n";
			return '';
			}
	}
}

sub _get_file_info {
	my $type = shift;
	if ( $type eq 'name' ) {
		return sub {
			my $document = Padre::Current->document;
			my $filename = $document->filename || $document->tempfile;
			warn "doc : $document $filename \n";
			return $filename;
		};
	} else {
		return sub {
			my $document = Padre::Current->document;
			my $filename = $document->filename || $document->tempfile;
			warn "doc : $document $filename \n";
			return ($filename) ? -s $filename : 0;
		};
	}
}

sub _get_line_info {
	my $type = shift;
	return sub {
		my $editor = Padre::Current->editor;
		my $pos    = $editor->GetCurrentPos;
		my $line   = $editor->GetCurrentLine;
		return $line + 1;
	};
}


1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
