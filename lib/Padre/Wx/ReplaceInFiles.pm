package Padre::Wx::ReplaceInFiles;

=pod

=head1 NAME

Padre::Wx::ReplaceInFiles - Replace in files, with the help of L<Ack>

=head1 DESCRIPTION

C<Padre::Wx::ReplaceInFiles> implements a search dialog used to replace recursively in
files. It is using C<Ack> underneath, for lots of nifty features.

=cut

use 5.008;
use strict;
use warnings;
use File::Basename    ();
use Padre::Current    ();
use Padre::DB         ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();
use Padre::Wx::Ack    ();

use Data::Dumper;

our $VERSION = '0.71';

my $iter;
my %opts;
my $panel_string_index = 9999999;

my $DONE_EVENT : shared = Wx::NewEventType;

sub on_replace_in_files {
	my $main    = shift;
	my $current = $main->current;

	# delay App::Ack loading till first use, to reduce memory
	# usage and init time.
	unless ( Padre::Wx::Ack->loaded ) {
		my $error = Padre::Wx::Ack->load;
		if ($error) {
			$main->error($error);
			return;
		}
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
		[   [ 'Wx::StaticText', undef, Wx::gettext('Search Term:') ],
			[ 'Wx::ComboBox', '_ack_term_', $term, $search ],
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Replace Text:') ],
			[ 'Wx::ComboBox', '_replace_term_', $term, $search ], # TODO
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Search Directory:') ],
			[ 'Wx::DirPickerCtrl', '_ack_dir_', $in_dir, Wx::gettext('Pick parent directory') ]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Search in Files/Types:') ],
			[ 'Wx::ComboBox', '_file_types_', '', $types ],
		],
		[   [],
			[   'Wx::CheckBox',
				'case_insensitive',
				Wx::gettext('Case &Insensitive'),
				( $config->find_case ? 0 : 1 )
			],
		],
		[   [],
			[   'Wx::CheckBox',
				'ignore_hidden_subdirs',
				Wx::gettext('I&gnore hidden subdirectories'),
				$config->find_nohidden,
			],
		],
		[   ['Wx::StaticLine'],
			['Wx::StaticLine'],
		],
		[   [],
			[ 'Wx::Button', '_replace_', 'Replace All' ],
			[ 'Wx::Button', '_cancel_',  Wx::wxID_CANCEL ],
		],
	);

	return \@layout;
}

sub dialog {
	my ( $main, $term, $directory ) = @_;

	my $layout = get_layout( $term, $directory );
	my $dialog = Padre::Wx::Dialog->new(
		parent => $main,
		title  => Wx::gettext('Replace in Files'),
		layout => $layout,
		width  => [ 160, 330 ],
		size   => Wx::wxDefaultSize,
		pos    => Wx::wxDefaultPosition,
	);

	$dialog->{_widgets_}->{_replace_}->SetDefault;

	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_replace_}, \&replace_clicked );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_cancel_},  \&cancel_clicked );

	Wx::Event::EVT_IDLE(
		$dialog,
		sub {
			$dialog->{_widgets_}->{_ack_term_}->SetFocus;
			Wx::Event::EVT_IDLE( $dialog, undef );
		}
	);

	return $dialog;
}

sub cancel_clicked {
	$_[0]->Destroy;
}

sub replace_clicked {
	my ( $dialog, $event ) = @_;

	my $search = _get_data_from($dialog);

	$search->{dir} ||= '.';
	return if not $search->{term};



	# really need to handle special characters.
	my $term = quotemeta $search->{term};

	# Ctrl+F $string - testing string to find
	#print "Search term: " . $search->{term} .  " and after: $term\n";
	my $main = Padre->ide->wx->main;

	@_ = (); # cargo cult or bug? see Wx::Thread / Creating new threads

	# TO DO kill the thread before closing the application

	# prepare \%opts
	%opts = ();

	$opts{regex}       = $term;
	$opts{search_term} = $search->{term};

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
		foreach my $i ( App::Ack::filetypes_supported() ) {
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

	# karl: borrowed this from ack hoping that will fix the ignore-case bug
	my $file_matching = $opts{f} || $opts{lines};
	if ( !$file_matching ) {
		$opts{regex} = App::Ack::build_regex( $opts{regex}, \%opts );
	}

	# check that all regexes do compile fine
	eval { App::Ack::check_regex( $opts{regex} ) };
	if ($@) {
		$main->error( 'Find in Files: error in regex ' . $opts{regex} );
		return;
	}


	my $what = App::Ack::get_starting_points( [ $search->{dir} ], \%opts );
	$iter = App::Ack::get_iterator( $what, \%opts );
	App::Ack::filetype_setup();

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

	TRANSACTION: {
		my $lock = Padre::Current->main->lock('DB');
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
	}

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

######################################
# Ack related

sub ack_done {
	my ( $main, $event ) = @_;

	my $data = $event->GetData;

	$main = Padre->ide->wx->main;

	print Dumper($data);

	return;
}

sub on_ack_thread {

	print Dumper($iter);
	print "--\n";
	print Dumper(\%opts);
	print "--\n";

	App::Ack::print_matches( $iter, \%opts );
}

sub print_results {
	my ($text) = @_;

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
	foreach my $i ( App::Ack::filetypes_supported() ) {
		$App::Ack::type_wanted{$i} = undef;
	}
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
