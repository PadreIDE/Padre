package Padre::Wx::Ack;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Wx::Dialog;
use Wx::Locale qw(:default);

my $iter;
my %opts;
my %stats;

our $VERSION = '0.20';
my $DONE_EVENT : shared = Wx::NewEventType;

my $ack_loaded = 0;
sub load_ack {
	my $minver = 1.86;
	my $error  = "App::Ack $minver required for this feature";

	# try to load app::ack - we don't require $minver in the eval to
	# provide a meaningful error message if needed.
	eval "use App::Ack"; ## no critic
	return "$error (module not installed)" if $@;
	return "$error (you have $App::Ack::VERSION installed)"
		if $App::Ack::VERSION < $minver;

	# redefine some app::ack subs to display results in padre's output
	{
		no warnings 'redefine';
		*{App::Ack::print_first_filename} = sub { print_results("$_[0]\n"); };
		*{App::Ack::print_separator}      = sub { print_results("--\n"); };
		*{App::Ack::print}                = sub { print_results($_[0]); };
		*{App::Ack::print_filename}       = sub { print_results("$_[0]$_[1]"); };
		*{App::Ack::print_line_no}        = sub { print_results("$_[0]$_[1]"); };
	}
	
	return;
}


sub on_ack {
	my ($mainwindow) = @_;

	# delay App::Ack loading till first use, to reduce memory
	# usage and init time.
	if ( ! $ack_loaded ) {
		my $error = load_ack();
		if ( $error ) {
			$mainwindow->error($error);
			return;
		}
		$ack_loaded = 1;
	}

	# clear %stats; for every request
	%stats = ();
	
	my $text   = $mainwindow->selected_text;
	$text = '' if not defined $text;
	
	my $dialog = dialog($mainwindow, $text);
	$dialog->Show(1);

	return;
}

sub find_clicked {
	my ($dialog, $event) = @_;

	my $search = _get_data_from( $dialog );

	$search->{dir} ||= '.';
	return if not $search->{term};
	
	my $mainwindow = Padre->ide->wx->main_window;

	@_ = (); # cargo cult or bug? see Wx::Thread / Creating new threads

	# TODO kill the thread before closing the application

	$opts{regex} = $search->{term};
	if (-f $search->{dir}) {
		$opts{all} = 1;
	}
	my $what = App::Ack::get_starting_points( [$search->{dir}], \%opts );
	fill_type_wanted();
	$iter = App::Ack::get_iterator( $what, \%opts );
	App::Ack::filetype_setup();

	$mainwindow->show_output(1);
	$mainwindow->{gui}->{output_panel}->clear;

	Wx::Event::EVT_COMMAND( $mainwindow, -1, $DONE_EVENT, \&ack_done );

	my $worker = threads->create( \&on_ack_thread );

	return;
}

sub _get_data_from {
	my ( $dialog ) = @_;

	my $data = $dialog->get_data;
	
	my $term = $data->{_ack_term_};
	my $dir  = $data->{_ack_dir_};
	
	$dialog->Destroy;
	
	my $config = Padre->ide->config;
	if ( $term ) {
		unshift @{$config->{ack_terms}}, $term;
		my %seen;
		@{$config->{ack_terms}} = grep {!$seen{$_}++} @{$config->{ack_terms}};
	}
	if ( $dir ) {
		unshift @{$config->{ack_dirs}}, $dir;
		my %seen;
		@{$config->{ack_dirs}} = grep {!$seen{$_}++} @{$config->{ack_dirs}};
	}
	
	return {
		term => $term,
		dir  => $dir,
	}
}

sub get_layout {
	my ( $term ) = shift;
	
	my $config = Padre->ide->config;
	
	my @layout = (
		[
			[ 'Wx::StaticText', undef,              gettext('Term:')],
			[ 'Wx::ComboBox',   '_ack_term_',       $term, $config->{ack_terms} ],
			[ 'Wx::Button',     '_find_',           Wx::wxID_FIND ],
		],
		[
			[ 'Wx::StaticText', undef,              gettext('Dir:')],
			[ 'Wx::ComboBox',   '_ack_dir_',        '', $config->{ack_dirs} ],
			[ 'Wx::Button',     '_pick_dir_',        gettext('Pick &directory')],
		],
		[
			[],
			[],
			[ 'Wx::Button',     '_cancel_',    Wx::wxID_CANCEL],
		],
	);
	return \@layout;
}

sub dialog {
	my ( $win, $term ) = @_;
	
	my $layout = get_layout($term);
	my $dialog = Padre::Wx::Dialog->new(
		parent => $win,
		title  => gettext("Ack"),
		layout => $layout,
		width  => [150, 200],
		size   => Wx::wxDefaultSize,
		pos    => Wx::wxDefaultPosition,
	);
	
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_find_},        \&find_clicked);
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_pick_dir_},    \&on_pick_dir);
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_cancel_},      \&cancel_clicked      );
	
	$dialog->{_widgets_}{_ack_term_}->SetFocus;

	return $dialog;
}

sub on_pick_dir {
	my ($dialog, $event) = @_;

	my $win = Padre->ide->wx->main_window;
	my $dir_dialog = Wx::DirDialog->new( $win, Wx::gettext("Select directory"), '');
	if ($dir_dialog->ShowModal == Wx::wxID_CANCEL) {
		return;
	}
	$dialog->{_widgets_}{_ack_dir_}->SetValue($dir_dialog->GetPath);

	return;
}

sub cancel_clicked {
	my ($dialog, $event) = @_;

	$dialog->Destroy;

	return;
}

sub ack_done {
	my( $mainwindow, $event ) = @_;

	my $data = $event->GetData;
	$mainwindow->{gui}->{output_panel}->AppendText($data);

	return;
}

sub on_ack_thread {
	App::Ack::print_matches( $iter, \%opts );
}

sub print_results {
	my ($text) = @_;
	
	#print "$text\n";
	
	# the first is filename, the second is line number, the third is matched line text
	$stats{printed_lines}++;
	# don't print filename again if it's just printed
	return if ( $stats{printed_lines} % 3 == 1 and
				$stats{last_matched_filename} and
				$stats{last_matched_filename} eq $text );
	$stats{last_matched_filename} = $text if ( $stats{printed_lines} % 3 == 1 );
	# new \n rules
	# 1, add \n before $filename expect the first filename
	if ( $stats{printed_lines} % 3 == 1 ) {
		$text .= "\n";
		$text = "\n$text" if ($stats{printed_lines} != 1);
	}
	# an extra space for line number
	$text .= ' ' if ( $stats{printed_lines} % 3 == 2 );

	#my $end = $result->get_end_iter;
	#$result->insert($end, $text);

	my $frame = Padre->ide->wx->main_window;
	my $threvent = Wx::PlThreadEvent->new( -1, $DONE_EVENT, $text );
	Wx::PostEvent( $frame, $threvent );


	return;
}



# see t/module.t in ack distro
sub fill_type_wanted {
	for my $i ( App::Ack::filetypes_supported() ) {
		$App::Ack::type_wanted{ $i } = undef;
	}
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
