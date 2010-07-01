package Padre::Wx::Dialog::SpecialValues;

# Insert special values such as dates in your code

use 5.008;
use strict;
use warnings;
use Padre::Wx         ();
use Padre::Wx::Dialog ();
use Padre::Current    ();

our $VERSION = '0.65';

my $categories = {
	Wx::gettext('Date/Time') => [
		{ label => Wx::gettext('Now'),   action => _get_date_info('now') },
		{ label => Wx::gettext('Today'), action => _get_date_info('today') },
		{ label => Wx::gettext('Year'),  action => _get_date_info('year') },
		{ label => Wx::gettext('Epoch'), action => _get_date_info('epoch') },
	],
	Wx::gettext('File') => [
		{   label  => Wx::gettext('Size'),
			action => sub { _get_file_info('size') }
		},
		{   label  => Wx::gettext('Name'),
			action => sub {
				_get_file_info('name');
				}
		},
		{   label  => Wx::gettext('Number of lines'),
			action => sub {
				_get_file_info('number of lines');
				}
		},
	],
};

my $cats_list = [ sort keys %$categories ];

sub get_layout {
	my ($config) = @_;

	my $default_cat_values = [ map { $_->{label} } @{ $categories->{ $cats_list->[0] } } ];

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
		title  => Wx::gettext('Insert Special Values'),
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
	my $values   = [ map { $_->{label} } @{ $categories->{$cat_name} } ];
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
	} elsif ( $type eq 'today' ) {
		return sub {
			my @localtime = localtime(time);
			return sprintf "%s-%02s-%02s", $localtime[5] + 1900, $localtime[4], $localtime[3];
			}
	} elsif ( $type eq 'year' ) {
		return sub {
			my @localtime = localtime(time);
			return $localtime[5] + 1900;
			}
	} elsif ( $type eq 'epoch' ) {
		return sub {
			return time;
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
	my $doc  = Padre::Current->document;
	my ($lines, $chars_with_space, $chars_without_space, $words, $newline_type,
		$encoding
	) = $doc->stats;

	if ( $type eq 'name' ) {
		return defined $doc->file ? $doc->{file}->filename : $doc->get_title;
	} elsif ( $type eq 'size' ) {
		my $filename = $doc->filename || $doc->tempfile;
		return ($filename) ? -s $filename : 0;
	} elsif ( $type eq 'number of lines' ) {
		return $lines;
	} else {
		warn "file info $type not implemented yet\n";
		return '';
	}
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
