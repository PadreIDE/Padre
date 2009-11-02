package Padre::Wx::Ack;

=pod

=head1 NAME

Padre::Wx::Ack - Find in files, using Ack

=head1 DESCRIPTION

C<Padre::Wx::Ack> implements a search dialog used to find recursively in
files. It is using C<Ack> underneath, for lots of nifty features.

=cut

use 5.008;
use strict;
use warnings;
use Padre::DB         ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();
use File::Basename    ();

our $VERSION = '0.49';

my $iter;
my %opts;
my %stats;
my $panel_string_index = 9999999;

my $DONE_EVENT : shared = Wx::NewEventType;

my $loaded = 0;

sub load {
	my $minver = 1.86;
	my $error  = "App::Ack $minver required for this feature";

	# try to load app::ack - we don't require $minver in the eval to
	# provide a meaningful error message if needed.
	eval "use App::Ack"; ## no critic
	if ($@) {
		return "$error (module not installed)";
	}
	if ( $App::Ack::VERSION < $minver ) {
		return "$error (you have $App::Ack::VERSION installed)";
	}

	# redefine some app::ack subs to display results in padre's output
	SCOPE: {
		no warnings 'redefine', 'once';
		*{App::Ack::print_first_filename} = sub { print_results("$_[0]\n"); };
		*{App::Ack::print_separator}      = sub { print_results("--\n"); };
		*{App::Ack::print}                = sub { print_results( $_[0] ); };
		*{App::Ack::print_filename}       = sub { print_results("$_[0]$_[1]"); };
		*{App::Ack::print_line_no}        = sub { print_results("$_[0]$_[1]"); };
	}

	return;
}

sub on_ack {
	my $main    = shift;
	my $current = $main->current;

	# delay App::Ack loading till first use, to reduce memory
	# usage and init time.
	unless ($loaded) {
		my $error = load();
		if ($error) {
			$main->error($error);
			return;
		}
		$loaded = 1;
	}

	my $project = $current->project;
	my $dialog  = dialog(
		$main,
		$current->text,
		$project ? $project->root : '',
	);
	$dialog->Show(1);

	return;
}

################################
# Dialog related

sub get_layout {
	my $term   = shift;
	my $dir    = shift;
	my $search = Padre::DB::History->recent('search');
	my $in_dir = Padre::DB::History->recent('find in');
	my $types  = Padre::DB::History->recent('find types');

	# default value is 1 for ignore_hidden_subdirs
	my $config = Padre->ide->config;

	my @layout = (
		[   [ 'Wx::StaticText', undef, Wx::gettext('Term:') ],
			[ 'Wx::ComboBox', '_ack_term_', $term, $search ],
			[ 'Wx::Button',   '_find_',     Wx::wxID_FIND ],
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Dir:') ],
			[ 'Wx::ComboBox', '_ack_dir_',  $dir, $in_dir ],
			[ 'Wx::Button',   '_pick_dir_', Wx::gettext('Pick &directory') ],
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('In Files/Types:') ],
			[ 'Wx::ComboBox', '_file_types_', '', $types ],
			[ 'Wx::Button',   '_cancel_',     Wx::wxID_CANCEL ],
		],
		[   [   'Wx::CheckBox',
				'case_insensitive',
				Wx::gettext('Case &Insensitive'),
				( $config->find_case ? 0 : 1 )
			],
		],
		[   [   'Wx::CheckBox',
				'ignore_hidden_subdirs',
				Wx::gettext('I&gnore hidden Subdirectories'),
				$config->find_nohidden,
			],
		],

	);

	return \@layout;
}

sub dialog {
	my ( $main, $term, $directory ) = @_;

	my $layout = get_layout( $term, $directory );
	my $dialog = Padre::Wx::Dialog->new(
		parent => $main,
		title  => Wx::gettext("Find in Files"),
		layout => $layout,
		width  => [ 190, 210 ],
		size   => Wx::wxDefaultSize,
		pos    => Wx::wxDefaultPosition,
	);

	$dialog->{_widgets_}->{_find_}->SetDefault;

	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_find_},     \&find_clicked );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_pick_dir_}, \&on_pick_dir );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_cancel_},   \&cancel_clicked );

	$dialog->{_widgets_}->{_ack_term_}->SetFocus;

	return $dialog;
}

sub on_pick_dir {
	my ( $dialog, $event ) = @_;

	my $main = Padre->ide->wx->main;

	my $default_dir = $dialog->{_widgets_}->{_ack_dir_}->GetValue;
	unless ($default_dir) { # we use currect editor
		my $filename = $main->current->filename;
		if ($filename) {
			$default_dir = File::Basename::dirname($filename);
		}
	}

	my $dir_dialog = Wx::DirDialog->new(
		$main,
		Wx::gettext("Select directory"),
		$default_dir
	);
	if ( $dir_dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	$dialog->{_widgets_}->{_ack_dir_}->SetValue( $dir_dialog->GetPath );

	return;
}

sub cancel_clicked {
	$_[0]->Destroy;
}

sub find_clicked {
	my ( $dialog, $event ) = @_;

	my $search = _get_data_from($dialog);

	$search->{dir} ||= '.';
	return if not $search->{term};

	my $main = Padre->ide->wx->main;

	@_ = (); # cargo cult or bug? see Wx::Thread / Creating new threads

	# TODO kill the thread before closing the application

	# prepare \%opts
	%opts = ();
	$opts{regex} = $search->{term};

	# ignore_hidden_subdirs
	if ( $search->{ignore_hidden_subdirs} ) {
		$opts{all} = 1;
	} else {
		$opts{u} = 1; # unrestricted
	}

	# file_type
	fill_type_wanted();
	if ( my $file_types = $search->{file_types} ) {
		my $is_regex = 1;
		my $wanted = ( $file_types =~ s/^no// ) ? 0 : 1;
		for my $i ( App::Ack::filetypes_supported() ) {
			if ( $i eq $file_types ) {
				$App::Ack::type_wanted{$i} = $wanted;
				$is_regex = 0;
				last;
			}
		}
		$opts{G} = quotemeta $file_types if ($is_regex);
	}

	# case_insensitive
	$opts{i} = $search->{case_insensitive} if $search->{case_insensitive};

	my $what = App::Ack::get_starting_points( [ $search->{dir} ], \%opts );
	$iter = App::Ack::get_iterator( $what, \%opts );
	App::Ack::filetype_setup();

	unless ( $main->{ack} ) {
		create_ack_pane($main);
	}
	$main->show_output(1);
	show_ack_output( $main, 1 );
	$main->{ack}->DeleteAllItems;

	Wx::Event::EVT_COMMAND( $main, -1, $DONE_EVENT, \&ack_done );

	my $worker = threads->create( \&on_ack_thread );

	return;
}

sub _get_data_from {
	my ($dialog)              = @_;
	my $data                  = $dialog->get_data;
	my $term                  = $data->{_ack_term_};
	my $dir                   = $data->{_ack_dir_};
	my $file_types            = $data->{_file_types_};
	my $case_insensitive      = $data->{case_insensitive};
	my $ignore_hidden_subdirs = $data->{ignore_hidden_subdirs};

	$dialog->Destroy;

	# Save our preferences
	my $config = Padre->ide->config;
	Padre::DB->begin;
	Padre::DB::History->create(
		type => 'search',
		name => $term,
	) if $term;
	Padre::DB::History->create(
		type => 'find in',
		name => $dir,
	) if $dir;
	Padre::DB::History->create(
		type => 'find type',
		name => $file_types,
	) if $file_types;
	Padre::DB->commit;

	$config->set( find_case => $case_insensitive ? 0 : 1 );
	$config->set( find_nohidden => $ignore_hidden_subdirs );

	return {
		term                  => $term,
		dir                   => $dir,
		file_types            => $file_types,
		case_insensitive      => $case_insensitive,
		ignore_hidden_subdirs => $ignore_hidden_subdirs,
	};
}

################################
# Ack pane related

sub create_ack_pane {
	my ($main) = @_;

	$main->{ack} = Wx::ListCtrl->new(
		$main->bottom,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_SINGLE_SEL | Wx::wxLC_NO_HEADER | Wx::wxLC_REPORT
	);

	$main->{ack}->InsertColumn( 0, Wx::gettext('Ack') );
	$main->{ack}->SetColumnWidth( 0, Wx::wxLIST_AUTOSIZE );

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$main,
		$main->{ack},
		\&on_ack_result_selected,
	);
}

sub show_ack_output {
	my $main = shift;
	my $on   = @_ ? $_[0] ? 1 : 0 : 1;
	my $bp   = \$main->{bottom};
	my $op   = \$main->{ack};
	my $idx  = ${$bp}->GetPageIndex( ${$op} );

	if ( $idx >= 0 ) {
		${$bp}->SetSelection($idx);
	} else {
		${$bp}->InsertPage(
			0,
			${$op},
			Wx::gettext("Ack"),
			1,
		);
		${$op}->Show;
	}
	$main->aui->GetPane('bottom')->Show;
	$main->aui->Update;

	return;
}

sub on_ack_result_selected {
	my ( $self, $event ) = @_;

	my $text = $event->GetItem->GetText;
	return if not defined $text;

	my ( $file, $line ) = ( $text =~ /^(.*?)\((\d+)\)\:/ );
	return unless $line;

	my $main = Padre->ide->wx->main;
	my $id   = $main->setup_editor($file);
	$main->on_nth_pane($id) if $id;

	my $page = $main->current->editor;
	$line--;
	$page->goto_line_centerize($line);
}

######################################
# Ack related

sub ack_done {
	my ( $main, $event ) = @_;

	my $data = $event->GetData;

	$main = Padre->ide->wx->main;
	$main->{ack}->InsertStringItem( $panel_string_index--, $data );
	$main->{ack}->SetColumnWidth( 0, Wx::wxLIST_AUTOSIZE );

	return;
}

sub on_ack_thread {

	# clear %stats; for every request
	%stats = (
		cnt_files   => 0,
		cnt_matches => 0,
	);

	App::Ack::print_matches( $iter, \%opts );

	# summary
	_send_text( '-' x 39 . "\n" ) if ( $stats{cnt_files} );
	_send_text("Found $stats{cnt_files} files and $stats{cnt_matches} matches\n");
}

sub print_results {
	my ($text) = @_;

	#print "$text\n";

	# the first is filename, the second is line number, the third is matched line text
	# while 'Binary file', there is ONLY filename
	$stats{printed_lines}++;

	# don't print filename again if it's just printed
	return
		if ($stats{printed_lines} % 3 == 1
		and $stats{last_matched_filename}
		and $stats{last_matched_filename} eq $text );
	if ( $stats{printed_lines} % 3 == 1 ) {
		if ( $text =~ /^Binary file/ ) {
			$stats{printed_lines} = $stats{printed_lines} + 2;
		}

		$stats{last_matched_filename} = $text;
		$stats{cnt_files}++;

		# chop last ':', add \n after $filename
		chop($text);
		$text = "Found '$opts{regex}' in '$text':\n";

		# new line between different files
		_send_text( '-' x 39 . "\n" );
	} elsif ( $stats{printed_lines} % 3 == 2 ) {
		$stats{cnt_matches}++;

		# use () to wrap the number, an extra space for line number
		$text =~ s/(\d+)/\($1\)/;
		$text .= ' ';
	}

	#my $end = $result->get_end_iter;
	#$result->insert($end, $text);

	# just print it when we have \n
	if ( $text =~ /[\r\n]/ ) {
		my $filename = $stats{last_matched_filename};
		chop($filename);
		$text = $filename . $stats{last_text} . $text if $stats{last_text};
		delete $stats{last_text};
	} else {
		$stats{last_text} .= $text;
		return;
	}

	_send_text($text);

	return;
}

sub _send_text {
	my $text = shift;

	# Reformat the text to remove non-printable characters
	$text =~ s/\n\z//g;
	$text =~ s/\t/        /g;

	my $frame = Padre->ide->wx->main;
	my $threvent = Wx::PlThreadEvent->new( -1, $DONE_EVENT, $text );
	Wx::PostEvent( $frame, $threvent );
}

# see t/module.t in ack distro
sub fill_type_wanted {
	for my $i ( App::Ack::filetypes_supported() ) {
		$App::Ack::type_wanted{$i} = undef;
	}
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
