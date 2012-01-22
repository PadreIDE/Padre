package Padre::Wx::Panel::Breakpoints;

use 5.008;
use strict;
use warnings;
use Padre::Util                 ();
use Padre::Wx                   ();
use Padre::Wx::Util             ();
use Padre::Wx::Icon             ();
use Padre::Wx::Role::View       ();
use Padre::Wx::FBP::Breakpoints ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::View
	Padre::Wx::FBP::Breakpoints
};

use constant {
	RED        => Wx::Colour->new('red'),
	DARK_GREEN => Wx::Colour->new( 0x00, 0x90, 0x00 ),
	BLUE       => Wx::Colour->new('blue'),
	GRAY       => Wx::Colour->new('gray'),
	DARK_GRAY  => Wx::Colour->new( 0x7f, 0x7f, 0x7f ),
	BLACK      => Wx::Colour->new('black'),
};

#######
# new
#######
sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->left;

	# Create the panel
	my $self = $class->SUPER::new($panel);

	$main->aui->Update;

	$self->set_up;

	return $self;
}

###############
# Make Padre::Wx::Role::View happy
###############

sub view_panel {
	'left';
}

sub view_label {
	Wx::gettext('Breakpoints');
}

sub view_close {
	$_[0]->main->show_breakpoints(0);
}

sub view_icon {
	Padre::Wx::Icon::find('actions/morpho3');
}

sub view_start {
	return;
}

sub view_stop {
	return;
}

###############
# Make Padre::Wx::Role::View happy end
###############

#######
# Method set_up
#######
sub set_up {
	my $self = shift;

	$self->{breakpoints_visable} = 0;

	# Setup the debug button icons
	$self->{refresh}->SetBitmapLabel( Padre::Wx::Icon::find('actions/view-refresh') );
	$self->{refresh}->Enable;

	$self->{delete_not_breakable}->SetBitmapLabel( Padre::Wx::Icon::find('actions/window-close') );
	$self->{delete_not_breakable}->Enable;

	$self->{set_breakpoints}->SetBitmapLabel( Padre::Wx::Icon::find('actions/breakpoints') );
	$self->{set_breakpoints}->Enable;

	$self->{delete_project_bp}->SetBitmapLabel( Padre::Wx::Icon::find('actions/x-document-close') );
	$self->{delete_project_bp}->Disable;

	# Update the checkboxes with their corresponding values in the
	# configuration
	$self->{show_project}->SetValue(0);
	$self->{show_project} = 0;

	$self->_setup_db;

	# TODO Active should be droped, just on show for now
	# Setup columns names, Active should be droped, just and order here
	# my @column_headers = qw( Path Line Active ); do not remove
	my @column_headers = qw( Path Line );
	my $index          = 0;
	for my $column_header (@column_headers) {
		$self->{list}->InsertColumn( $index++, Wx::gettext($column_header) );
	}

	# Tidy the list
	Padre::Wx::Util::tidy_list( $self->{list} );

	return;
}

##########################
# Event Handlers
#######
# event handler delete_not_breakable_clicked
#######
sub on_delete_not_breakable_clicked {
	my $self       = shift;
	my $editor     = $self->current->editor;
	my $sql_select = "WHERE filename = \"$self->{current_file}\" AND active = 0";
	my @tuples     = $self->{debug_breakpoints}->select($sql_select);
	my $index      = 0;

	for ( 0 .. $#tuples ) {

		# say 'delete me';
		$editor->MarkerDelete(
			$tuples[$_][2] - 1,
			Padre::Constant::MARKER_BREAKPOINT()
		);
		$editor->MarkerDelete(
			$tuples[$_][2] - 1,
			Padre::Constant::MARKER_NOT_BREAKABLE()
		);

	}
	$self->{debug_breakpoints}->delete("WHERE filename = \"$self->{current_file}\" AND active = 0");
	$self->_update_list;
	return;
}

#######
# event handler on_refresh_click
#######
sub on_refresh_click {
	my $self     = shift;
	my $document = $self->current->document;

	$self->{project_dir}  = $document->project_dir;
	$self->{current_file} = $document->filename;

	$self->_update_list;

	return;
}

#######
# event handler breakpoint_clicked
#######
sub on_set_breakpoints_clicked {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document;
	my $editor   = $current->editor;
	my %bp_action;
	$self->_setup_db;

	# $self->running or return;
	$self->{current_file} = $document->filename;
	$self->{current_line} = $editor->GetCurrentLine + 1;
	$bp_action{line}      = $self->{current_line};

	# dereferance array and test for contents
	if ($#{ $self->{debug_breakpoints}
				->select("WHERE filename = \"$self->{current_file}\" AND line_number = \"$self->{current_line}\"")
		} >= 0
		)
	{

		# say 'delete me';
		$editor->MarkerDelete(
			$self->{current_line} - 1,
			Padre::Constant::MARKER_BREAKPOINT()
		);
		$editor->MarkerDelete(
			$self->{current_line} - 1,
			Padre::Constant::MARKER_NOT_BREAKABLE()
		);
		$self->_delete_bp_db;
		$bp_action{action} = 'delete';

	} else {

		# say 'create me';
		$self->{bp_active} = 1;
		$editor->MarkerAdd(
			$self->{current_line} - 1,
			Padre::Constant::MARKER_BREAKPOINT()
		);
		$self->_add_bp_db;
		$bp_action{action} = 'add';
	}
	$self->on_refresh_click;
	return \%bp_action;
}

#######
# event handler on_show_project_click
#######
sub on_show_project_click {
	my ( $self, $event ) = @_;

	if ( $event->IsChecked ) {
		$self->{show_project} = 1;
		$self->{delete_project_bp}->Enable;

	} else {
		$self->{show_project} = 0;
		$self->{delete_project_bp}->Disable;

	}

	$self->on_refresh_click;

	return;
}

#######
# event handler delete_project_bp_clicked
#######
sub on_delete_project_bp_clicked {
	my $self       = shift;
	my $editor     = $self->current->editor;
	my $sql_select = 'ORDER BY filename ASC';
	my @tuples     = $self->{debug_breakpoints}->select($sql_select);
	my $index      = 0;

	for ( 0 .. $#tuples ) {

		if ( $tuples[$_][1] =~ m/^ $self->{project_dir} /sxm ) {

			$editor->MarkerDelete(
				$tuples[$_][2] - 1,
				Padre::Constant::MARKER_BREAKPOINT()
			);
			$editor->MarkerDelete(
				$tuples[$_][2] - 1,
				Padre::Constant::MARKER_NOT_BREAKABLE()
			);
			$self->{debug_breakpoints}->delete("WHERE filename = \"$tuples[$_][1]\" ");
		}
	}

	$self->on_refresh_click;
	return;
}

###############
# Debug Breakpoint DB
########
# internal method _setup_db connector
#######
sub _setup_db {
	my $self = shift;

	# set padre db relation
	$self->{debug_breakpoints} = ('Padre::DB::DebugBreakpoints');

	return;
}

#######
# internal method _add_bp_db
#######
sub _add_bp_db {
	my $self = shift;

	$self->{debug_breakpoints}->create(
		filename    => $self->{current_file},
		line_number => $self->{current_line},
		active      => $self->{bp_active},
		last_used   => time(),
	);

	return;
}

#######
# internal method _delete_bp_db
#######
sub _delete_bp_db {
	my $self = shift;

	$self->{debug_breakpoints}
		->delete("WHERE filename = \"$self->{current_file}\" AND line_number = \"$self->{current_line}\"");

	return;
}

#######
# Composed Method,
# display any relation db
#######
sub _update_list {
	my $self   = shift;
	my $editor = $self->current->editor;

	# Clear ListCtrl items
	$self->{list}->DeleteAllItems;

	my $sql_select = 'ORDER BY filename DESC, line_number DESC';
	my @tuples     = $self->{debug_breakpoints}->select($sql_select);

	my $index = 0;
	my $item  = Wx::ListItem->new;
	for ( 0 .. $#tuples ) {

		if ( $tuples[$_][1] =~ m/^ $self->{project_dir} /sxm ) {
			if ( $tuples[$_][1] =~ m/ $self->{current_file} $/sxm ) {
				$item->SetId($index);
				$self->{list}->InsertItem($item);
				if ( $tuples[$_][3] == 1 ) {
					$self->{list}->SetItemTextColour( $index, BLUE );
					$editor->MarkerAdd(
						$tuples[$_][2] - 1,
						Padre::Constant::MARKER_BREAKPOINT()
					);
				} else {
					$self->{list}->SetItemTextColour( $index, DARK_GRAY );
					$editor->MarkerAdd(
						$tuples[$_][2] - 1,
						Padre::Constant::MARKER_NOT_BREAKABLE()
					);
				}
				$self->{list}->SetItem( $index, 1, ( $tuples[$_][2] ) );
				$tuples[$_][1] =~ s/^ $self->{project_dir} //sxm;
				$self->{list}->SetItem( $index, 0, ( $tuples[$_][1] ) );

				# TODO comment out just on show for now, do not remove
				# $self->{list}->SetItem( $index++, 2, ( $tuples[$_][3] ) );

			}

			if ( $self->{show_project} == 1 ) {

				# we need to switch around due to previously stripping project_dir
				if ( $self->{current_file} !~ m/ $tuples[$_][1] $/sxm ) {

					$item->SetId($index);
					$self->{list}->InsertItem($item);
					$self->{list}->SetItemTextColour( $index, DARK_GREEN );

					if ( $tuples[$_][3] == 0 ) {
						$self->{list}->SetItemTextColour( $index, DARK_GRAY );
					}
					$self->{list}->SetItem( $index, 1, ( $tuples[$_][2] ) );
					$tuples[$_][1] =~ s/^ $self->{project_dir} //sxm;
					$self->{list}->SetItem( $index, 0, ( $tuples[$_][1] ) );

					# TODO comment out just on show for now, do not remove
					# $self->{list}->SetItem( $index++, 2, ( $tuples[$_][3] ) );

				}
			}
		}

		Padre::Wx::Util::tidy_list( $self->{list} );
	}

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
