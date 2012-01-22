package Padre::Wx::Dialog::Positions;

# TODO: This has no place as a separate class, and shouldn't be under dialogs,
# and shouldn't store local class data. Move into Padre::Wx::Main???

use 5.008;
use strict;
use warnings;
use Padre::DB ();
use Padre::Wx ();

our $VERSION = '0.94';

my @positions;

=head1 NAME

Padre::Wx::Dialog::Positions - Go to previous (or earlier) position

=head1 SYNOPSIS

In the places of the code before jumping to some
other location add:

  require Padre::Wx::Dialog::Positions;
  Padre::Wx::Dialog::Positions->set_position

=head1 DESCRIPTION

Remember position before certain movements 
and allow the user to jump to the earlier 
positions and then maybe back to the newer ones.

The location that will be remember are
the location before and after non-simple 
movements, for example:

=over 4

=item *

before/after jump to function declaration

=item *

before/after jump to variable declaration

=item *

before/after goto line number

=item *

before/after goto search result

=back

=cut

# TO DO Look for page_history and see if this can be united
# also the Bookmarks are similar a bit

# TO DO add keyboard short-cut ?
# TO DO add item next to buttons under the menues
# TO DO reset the rest of the history when someone moves forward from the middle
#    A, B, C,  -> goto(B), D  then the history should be A, B, D   I think.

sub set_position {
	my $class = shift;

	my $main    = Padre::Current->main;
	my $current = $main->current;
	my $editor  = $current->editor or return;
	my $path    = $current->filename;
	return unless defined $path;

	# TO DO Cannot (yet) set position in unsaved document

	my $line   = $editor->GetCurrentLine;
	my $file   = File::Basename::basename( $path || '' );
	my ($name) = $editor->GetLine($line);
	$name =~ s/\r?\n?$//;

	push @positions,
		{
		name => $name,
		file => $path,
		line => $line,
		};

	return;
}

sub goto_prev_position {
	my $class = shift;
	my $main  = shift;

	return _no_positions_yet($main) if not @positions;
	$class->goto_position( $main, scalar(@positions) - 1 );
	return;
}

sub _no_positions_yet {
	my $main = shift;
	$main->message(
		Wx::gettext("There are no positions saved yet"),
		Wx::gettext("Show previous positions")
	);
	return;
}

sub show_positions {
	my $class = shift;
	my $main  = shift;

	return _no_positions_yet($main) if not @positions;

	my $position = $main->single_choice(
		Wx::gettext('Choose File'),
		'',
		[   reverse map {
				sprintf(
					Wx::gettext("%s. Line: %s File: %s - %s"),
					$_,
					$positions[ $_ - 1 ]{line},
					$positions[ $_ - 1 ]{file},
					$positions[ $_ - 1 ]{name}
					)
				} 1 .. @positions
		],
	);
	return if not defined $position;
	if ( $position =~ /^(\d+)\./ ) {
		$class->goto_position( $main, $1 - 1 );
	}
	return;
}

sub goto_position {
	my $class = shift;
	my $main  = shift;
	my $pos   = shift;

	return if not defined $pos or $pos !~ /^\d+$/;
	return if not defined $positions[$pos];

	# $main->error( "" );

	# Is the file already open
	my $file   = $positions[$pos]{file};
	my $line   = $positions[$pos]{line};
	my $pageid = $main->editor_of_file($file);

	unless ( defined $pageid ) {

		# Load the file
		if ( -e $file ) {
			$main->setup_editor($file);
			$pageid = $main->editor_of_file($file);
		}
	}

	# Go to the relevant editor and row
	if ( defined $pageid ) {
		$main->on_nth_pane($pageid);
		my $page = $main->notebook->GetPage($pageid);
		$page->goto_line_centerize($line);
	}

	return;
}


1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
