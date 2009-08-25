package Padre::Wx::Dialog::Snippets;

# Insert snippets in your code

use 5.008;
use strict;
use warnings;
use Padre::Wx         ();
use Padre::Wx::Dialog ();
use Padre::Current    ();

our $VERSION = '0.44';

sub get_layout {
	my ($config) = @_;

	my $cats = Padre::DB->find_snipclasses;
	unshift @$cats, Wx::gettext('All');
	my $snippets = Padre::DB->find_snipnames;

	my @layout = (
		[ [ 'Wx::StaticText', undef, Wx::gettext('Class:') ],   [ 'Wx::Choice', '_find_cat_',     $cats ], ],
		[ [ 'Wx::StaticText', undef, Wx::gettext('Snippet:') ], [ 'Wx::Choice', '_find_snippet_', $snippets ], ],
		[ [], [ 'Wx::Button', '_insert_', Wx::gettext('&Insert') ], [ 'Wx::Button', '_cancel_', Wx::wxID_CANCEL ], ],
		[ ['Wx::StaticLine'], ['Wx::StaticLine'], ],
		[ [], [ 'Wx::Button', '_edit_', Wx::gettext('&Edit') ], [ 'Wx::Button', '_add_', Wx::gettext('&Add') ], ],
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
		title  => Wx::gettext("Snippets"),
		layout => $layout,
		width  => [ 150, 200 ],
	);

	Wx::Event::EVT_CHOICE( $dialog, $dialog->{_widgets_}->{_find_cat_}, \&find_category );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_insert_}, \&get_snippet );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_cancel_}, \&cancel_clicked );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_edit_},   \&edit_snippet );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_add_},    \&add_snippet );

	$dialog->{_widgets_}->{_find_cat_}->SetFocus;
	$dialog->{_widgets_}->{_insert_}->SetDefault;

	return $dialog;
}

sub snippets {
	my $class  = shift;
	my $main   = shift;
	my $dialog = $class->dialog( $main, {} );
	$dialog->Show(1);
	return;
}

sub _get_catno {
	my $dialog = shift;
	my $data   = $dialog->get_data;
	my $catno  = $data->{_find_cat_};
	return $catno ? @{ Padre::DB->find_snipclasses }[ $catno - 1 ] : '';
}

sub find_category {
	my $dialog   = shift;
	my $cat      = _get_catno($dialog);
	my $snippets = Padre::DB->find_snipnames($cat);
	my $field    = $dialog->{_widgets_}->{_find_snippet_};
	$field->Clear;
	$field->AppendItems($snippets);
	$field->SetSelection(0);
	return;
}

sub get_snippet_text {
	my $cat     = shift;
	my $snipno  = shift;
	my @choices = map { $_->[3] } @{ Padre::DB->find_snippets($cat) };
	return $choices[$snipno];
}

sub get_snippet {
	my $dialog = shift;
	my $data   = $dialog->get_data or return;
	my $cat    = _get_catno($dialog);
	my $snipno = $data->{_find_snippet_};
	my $text   = get_snippet_text( $cat, $snipno );
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

sub snippet_layout {
	my ($snippet) = @_;

	my @layout = (
		[ [ 'Wx::StaticText', undef, Wx::gettext('Category:') ], [ 'Wx::TextCtrl', 'category', $snippet->[1] ], ],
		[ [ 'Wx::StaticText', undef, Wx::gettext('Name:') ],     [ 'Wx::TextCtrl', 'name',     $snippet->[2] ], ],
		[ [ 'Wx::StaticText', undef, Wx::gettext('Snippet:') ],  [ 'Wx::TextCtrl', 'snippet',  $snippet->[3], 400 ], ],
		[ [], [ 'Wx::Button', '_save_', Wx::gettext('&Save') ], [ 'Wx::Button', '_cancel_', Wx::wxID_CANCEL ], ],
	);
	return \@layout;
}

sub snippet_dialog {
	my ( $dialog, $snippet ) = @_;

	my $layout      = snippet_layout($snippet);
	my $snip_dialog = Padre::Wx::Dialog->new(
		parent => $dialog,
		title  => Wx::gettext("Edit/Add Snippets"),
		layout => $layout,
		width  => [ 300, 500 ],
	);

	Wx::Event::EVT_BUTTON( $snip_dialog, $snip_dialog->{_widgets_}->{_save_}, \&save_snippet );
	Wx::Event::EVT_BUTTON( $dialog,      $dialog->{_widgets_}->{_cancel_},    \&cancel_clicked );

	$snip_dialog->{_widgets_}->{category}->SetFocus;

	return $snip_dialog;
}

my $snippet_number;

sub edit_snippet {
	my ( $dialog, $event ) = @_;

	my $data    = $dialog->get_data or return;
	my $cat     = _get_catno($dialog);
	my $snipno  = $data->{_find_snippet_};
	my $choices = Padre::DB->find_snippets($cat);
	$snippet_number = $choices->[$snipno]->[0];
	my $snip_dialog = snippet_dialog( $dialog, $choices->[$snipno] );
	$snip_dialog->show_modal;

	return;
}

sub add_snippet {
	my ( $dialog, $event ) = @_;

	undef $snippet_number;

	my $snip_dialog = snippet_dialog( $dialog, [ '', '', '' ] );
	$snip_dialog->show_modal;

	return;
}

sub save_snippet {
	my ( $dialog, $event ) = @_;

	my $data = $dialog->get_data or return;

	if ( defined $snippet_number ) {
		Padre::DB->do(
			"update snippets set category = ?, name = ?, snippet = ? where id = ?",
			{}, $data->{category}, $data->{name}, $data->{snippet}, $snippet_number,
		);
	} else {
		Padre::DB::Snippets->create(
			mimetype => Padre::Current->document->guess_mimetype,
			category => $data->{category},
			name     => $data->{name},
			snippet  => $data->{snippet},
		);
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
