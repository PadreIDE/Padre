package Padre::Wx::Dialog::Bookmarks;

use strict;
use warnings;

use List::Util   qw(max);
use Data::Dumper qw(Dumper);

use Padre::Wx;
use Padre::Wx::Dialog;
use Wx::Locale qw(:default);

our $VERSION = '0.24';

# workaround: need to be accessible from outside in oder to write unit test ( t/03-wx.t )
my $dialog;
sub get_dialog { return $dialog };

sub get_layout {
	my ($text, $shortcuts) = @_;
	
	my @layout;
	if ($text) {
		push @layout, [['Wx::TextCtrl', 'entry', $text]];
	}
	push @layout,
		[
			['Wx::StaticText', undef, gettext("Existing bookmarks:")],
		],
		[
			['Wx::Treebook',   'tb', $shortcuts],
		],
		[
			['Wx::Button',     'ok',     Wx::wxID_OK],
			['Wx::Button',     'cancel', Wx::wxID_CANCEL],
		];

	if (@$shortcuts) {
		push @{ $layout[-1] }, 
			['Wx::Button',     'delete', Wx::wxID_DELETE];
		push @{ $layout[-1] }, 
			['Wx::Button',     'delete_all', gettext('Delete &All')];
	}
	return \@layout;
}


sub dialog {
	my ($class, $main, $text) = @_;

	my $title = $text ? gettext("Set Bookmark") : gettext("GoTo Bookmark");
	my $config = Padre->ide->config;
	my @shortcuts = sort keys %{ $config->{bookmarks} };

	my $layout = get_layout($text, \@shortcuts);
	$dialog = Padre::Wx::Dialog->new(
		parent   => $main,
		title    => $title,
		layout   => $layout,
		width    => [300, 50],
	);
	if ($dialog->{_widgets_}{entry}) {
		$dialog->{_widgets_}{entry}->SetSize(10 * length $text, -1);
	}

#	foreach my $b (qw(ok cancel delete)) {
#		print "$b ", join (':', $dialog->{_widgets_}{ok}->GetSizeWH), "\n";
#	}
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{ok},      sub { $dialog->EndModal(Wx::wxID_OK) } );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{cancel},  sub { $dialog->EndModal(Wx::wxID_CANCEL) } );
	$dialog->{_widgets_}{ok}->SetDefault;

	if ($dialog->{_widgets_}{delete}) {
		Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{delete},     \&on_delete_bookmark );
		Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{delete_all}, \&on_delete_all_bookmark );
	}

	if ($text) {
		$dialog->{_widgets_}{entry}->SetFocus;
	} else {
		$dialog->{_widgets_}{tb}->SetFocus;
	}

	return $dialog;
}

sub _get_data {
	my ($dialog) = @_;

	my %data;
	my $shortcut = $dialog->{_widgets_}{entry}->GetValue;
	$shortcut =~ s/:/ /g; # YAML::Tiny limitation
	$data{shortcut} = $shortcut;
	$dialog->Destroy;
	$dialog = undef;
	return ($dialog, \%data);
}

sub set_bookmark {
	my $class    = shift;
	my $main     = shift;
	my $current  = $main->current;
	my $editor   = $current->editor or return;
	my $path     = $current->filename;
	my $line     = $editor->GetCurrentLine;
	my $file     = File::Basename::basename($path || '');
	my $dialog   = $class->dialog(
		$main,
		sprintf(gettext("%s line %s"), $file, $line)
	);
	$dialog->show_modal or return;

	my $data     = _get_data($dialog);
	my $config   = Padre->ide->config;
	my $shortcut = delete $data->{shortcut} or return;
	
	$data->{file}   = $path;
	$data->{line}   = $line;
	$config->{bookmarks}->{$shortcut} = $data;

	return;
}

sub goto_bookmark {
	my ($class, $main) = @_;

	my $dialog    = $class->dialog($main);
	return if not $dialog->show_modal;
	
	my $config    = Padre->ide->config;
	my $selection = $dialog->{_widgets_}{tb}->GetSelection;
	my @shortcuts = sort keys %{ $config->{bookmarks} };
	my $bookmark  = $config->{bookmarks}{ $shortcuts[$selection] };

	my $file      = $bookmark->{file};
	my $line      = $bookmark->{line};
	my $pageid    = $bookmark->{pageid};

	if (not defined $pageid) {
		# find if the given file is in memory
		$pageid = $main->find_editor_of_file($file);
	}
	if (not defined $pageid) {
		# load the file
		if (-e $file) {
			$main->setup_editor($file);
			$pageid = $main->find_editor_of_file($file);
		}
	}

	# go to the relevant editor and row
	if (defined $pageid) {
		$main->on_nth_pane($pageid);
		my $page = $main->notebook->GetPage($pageid);
		$page->goto_line_centerize($line);
	}

	return;
}

sub on_delete_bookmark {
	my ($dialog, $event) = @_;

	my $selection = $dialog->{_widgets_}{tb}->GetSelection;
	my $config    = Padre->ide->config;
	my @shortcuts = sort keys %{ $config->{bookmarks} };
	
	delete $config->{bookmarks}{ $shortcuts[$selection] };
	$dialog->{_widgets_}{tb}->DeletePage($selection);

	return;
}

sub on_delete_all_bookmark {
	my ($dialog, $event) = @_;

	my $config    = Padre->ide->config;
	$config->{bookmarks} = {}; # clear
	
	$dialog->{_widgets_}{tb}->DeleteAllPages();

	return;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
