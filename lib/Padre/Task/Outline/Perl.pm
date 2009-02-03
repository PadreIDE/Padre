package Padre::Task::Outline::Perl;

use strict;
use warnings;

our $VERSION = '0.26';

use base 'Padre::Task::Outline';

use version;

=pod

=head1 NAME

Padre::Task::Outline::Perl - Perl document outline structure info 
gathering in the background

=head1 SYNOPSIS

  # by default, the text of the current document
  # will be fetched as will the document's notebook page.
  my $task = Padre::Task::Outline::Perl->new;
  $task->schedule;
  
  my $task2 = Padre::Task::Outline::Perl->new(
    text          => Padre::Current->document->text_get,
    editor        => Padre::Current->editor,
  );
  $task2->schedule;

=head1 DESCRIPTION

This class implements structure info gathering of Perl documents in
the background.
Also the updating of the GUI is implemented here, because other 
languages might have different outline structures.
It inherits from L<Padre::Task::Outline>.
Please read its documentation!

=cut

sub run {
	my $self = shift;
	$self->_get_outline;
	return 1;
}

sub _get_outline {
	# TODO switch to using File::PackageIndexer
	# (which needs to be modified / extended first)
	my $self = shift;

	my $outline = [];

	require PPI::Find;
	require PPI::Document;

	my $ppi_doc = PPI::Document->new( \$self->{text} );

	return {} unless defined($ppi_doc);

	$ppi_doc->index_locations;

	my $find = PPI::Find->new(
		sub {
			return 1 if
				   ref $_[0] eq 'PPI::Statement::Package'
				or ref $_[0] eq 'PPI::Statement::Include'
				or ref $_[0] eq 'PPI::Statement::Sub'
		}
	);

	my @things = $find->in($ppi_doc);
	my $cur_pkg = {};
	my $not_first_one = 0;
	foreach my $thing (@things) {
		if ( ref $thing eq 'PPI::Statement::Package' ) {
			if ( $not_first_one ) {
				if ( not $cur_pkg->{name} ) {
					$cur_pkg->{name} = 'main';
				}
				push @{$outline}, $cur_pkg;
				$cur_pkg = {};
			}
			$not_first_one = 1;
			$cur_pkg->{name} = $thing->namespace;
			$cur_pkg->{line} = $thing->location->[0];
		}
		elsif ( ref $thing eq 'PPI::Statement::Include' ) {
			next if $thing->type eq 'no';
			if ( $thing->pragma ) {
				push @{ $cur_pkg->{pragmata} }, { name => $thing->pragma, line => $thing->location->[0] };
			}
			elsif ( $thing->module ) {
				push @{ $cur_pkg->{modules} }, { name => $thing->module, line => $thing->location->[0] };
			}
		}
		elsif ( ref $thing eq 'PPI::Statement::Sub' ) {
			push @{ $cur_pkg->{methods} }, { name => $thing->name, line => $thing->location->[0] };
		}
	}

	if ( not $cur_pkg->{name} ) {
		$cur_pkg->{name} = 'main';
	}
	push @{$outline}, $cur_pkg;

	$self->{outline} = $outline;
	return;
}

sub update_gui {
	my $self         = shift;
	my $last_outline = shift;
	my $outline      = $self->{outline};
	my $outlinebar   = Padre->ide->wx->main->outline;
	my $editor       = $self->{main_thread_only}->{editor};

	$outlinebar->Freeze;

	# Clear out the existing stuff
	# TODO extract data for keeping (sub)trees collapsed/expanded (see below)
	#if ( $outlinebar->GetCount > 0 ) {
	#	my $r = $outlinebar->GetRootItem;
	#	warn ref $r;
	#	use Data::Dumper;
	#	my ( $fc, $cookie ) = $outlinebar->GetFirstChild($r);
	#	warn ref $fc;
	#	warn $outlinebar->GetItemText($fc) . ': ' . Dumper( $outlinebar->GetPlData($fc) );
	#}
	$outlinebar->clear;

	require Padre::Wx;
	# If there is no structure, clear the outline pane and return.
	unless ( $outline ) {
		return;
	}

	# Again, slightly differently
	unless ( @$outline ) {
		return 1;
	}

	# Add the hidden unused root
	my $root = $outlinebar->AddRoot(
		Wx::gettext('Outline'),
		-1,
		-1,
		Wx::TreeItemData->new('')
	);

	# Update the outline pane
	_update_treectrl( $outlinebar, $outline, $root );

	# Set Perl5 specific event handler
	Wx::Event::EVT_TREE_ITEM_RIGHT_CLICK(
		$outlinebar,
		$outlinebar,
		\&_on_tree_item_right_click,
	);

	# TODO Expanding all is not acceptable: We need to keep the state
	# (i.e., keep the pragmata subtree collapsed if it was collapsed
	# by the user)
	#$outlinebar->ExpandAll;
	$outlinebar->GetBestSize;

	$outlinebar->Thaw;
	return 1;
}

sub _on_tree_item_right_click {
	my ( $outlinebar, $event ) = @_;
	my $showMenu = 0;

	my $menu = Wx::Menu->new;
	my $itemData = $outlinebar->GetPlData( $event->GetItem );

	if ( defined($itemData) && defined( $itemData->{line} ) && $itemData->{line} > 0 ) {
		my $goTo = $menu->Append( -1, Wx::gettext("&GoTo Element") );
		Wx::Event::EVT_MENU( $outlinebar, $goTo,
			sub { $outlinebar->on_tree_item_activated($event); },
		);
		$showMenu++;
	}

	if ( 
		defined($itemData)
		&& defined( $itemData->{type} ) 
		&& ( $itemData->{type} eq 'modules' || $itemData->{type} eq 'pragmata' )
	) {
		my $pod = $menu->Append( -1, Wx::gettext("Open &Documentation") );
		Wx::Event::EVT_MENU( $outlinebar, $pod,
			sub {
				# TODO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
				my $help = Padre::Wx::DocBrowser->new;
                		$help->help( $itemData->{name} );
				$help->SetFocus;
				$help->Show(1);
				return;
			},
		);
		$showMenu++;
	}
		

	if ( $showMenu > 0 ) {
		my $x = $event->GetPoint->x;
		my $y = $event->GetPoint->y;
		$outlinebar->PopupMenu( $menu, $x, $y );
	}
	return;
}

sub _update_treectrl {
	my ( $outlinebar, $outline, $root ) = @_;

	foreach my $pkg ( @{ $outline } ) {
                my $branch = $outlinebar->AppendItem(
                        $root,
                        $pkg->{name},
                        -1,
                        -1,
                        Wx::TreeItemData->new( {
                                line => $pkg->{line},
                                name => $pkg->{name},
				type => 'package',
                        } )
                );
                foreach my $type ( qw(pragmata modules methods) ) {
                        _add_subtree( $outlinebar, $pkg, $type, $branch );
                }
                $outlinebar->Expand($branch);
        }

	return;
}

sub _add_subtree {
	my ( $outlinebar, $pkg, $type, $root ) = @_;

	my $type_elem = undef;
	if ( defined($pkg->{$type}) && scalar(@{ $pkg->{$type} }) > 0 ) {
		$type_elem = $outlinebar->AppendItem(
			$root,
			ucfirst($type),
			-1,
			-1,
			Wx::TreeItemData->new()
		);
		foreach my $item ( sort { $a->{name} cmp $b->{name} } @{ $pkg->{$type} } ) {
			$outlinebar->AppendItem(
				$type_elem,
				$item->{name},
				-1,
				-1,
				Wx::TreeItemData->new( {
					line => $item->{line},
					name => $item->{name},
					type => $type,
				} )
			);
		}
	}
	if ( defined $type_elem ) {
		if ( $type eq 'methods' ) {
			$outlinebar->Expand($type_elem);
		}
		else {
			$outlinebar->Collapse($type_elem);
		}
	}

	return;
}

1;

__END__

=head1 SEE ALSO

This class inherits from L<Padre::Task::Outline> which
in turn is a L<Padre::Task> and its instances can be scheduled
using L<Padre::TaskManager>.

=head1 AUTHOR

Heiko Jansen C<heiko_jansen@web.de>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Gabor Szabo.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
