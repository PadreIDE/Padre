package Padre::Task::Outline;

use strict;
use warnings;
use Params::Util   qw{_CODE _INSTANCE};
use Padre::Task    ();
use Padre::Current ();
use Padre::Wx      ();

our $VERSION = '0.25';
our @ISA     = 'Padre::Task';

=pod

=head1 NAME

Padre::Task::Outline - Generic background processing task to
gather structure info on the current document

=head1 SYNOPSIS

  package Padre::Task::Outline::MyLanguage;
  use base 'Padre::Task::Outline';
  
  sub run {
          my $self = shift;
          my $doc_text = $self->{text};
          # black magic here
          $self->{outline} = ...;
          return 1;
  };
  
  1;
  
  # elsewhere:
  
  # by default, the text of the current document
  # will be fetched as will the document's notebook page.
  my $task = Padre::Task::Outline::MyLanguage->new();
  $task->schedule;
  
  my $task2 = Padre::Task::Outline::MyLanguage->new(
    text          => Padre::Current->document->text_get,
    editor => Padre::Current->editor,
  );
  $task2->schedule;

=head1 DESCRIPTION

This is a base class for all tasks that need to do
expensive structure info gathering in a background task.

You can either let C<Padre::Task::Outline> fetch the
Perl code for parsing from the current document
or specify it as the "C<text>" parameter to
the constructor.

To create a outline gatherer for a given document type C<Foo>,
you create a subclass C<Padre::Task::Outline::Foo> and
implement the C<run> method which uses the C<$self-E<gt>{text}>
attribute of the task object for its nefarious structure info gathering
purposes and then stores the result in the C<$self-E<gt>{outline}>
attribute of the object. The result should be a data structure of the
form defined in the documentation of the C<Padre::Document::get_outline>
method. See L<Padre::Document>.

This base class implements all logic necessary to update the GUI
with the structure info in a C<finish()> hook. If you want
to implement your own C<finish()>, make sure to call C<$self-E<gt>SUPER::finish>
for this reason.

=cut

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	unless ( defined $self->{text} ) {
		$self->{text} = Padre::Current->document->text_get;
	}

	# put notebook page and callback into main-thread-only storage
	$self->{main_thread_only} ||= {};
	my $editor = $self->{editor} || $self->{main_thread_only}->{editor};
	my $on_finish     = $self->{on_finish}     || $self->{main_thread_only}->{on_finish};
	delete $self->{editor};
	delete $self->{on_finish};
	unless ( defined $editor ) {
		$editor = Padre::Current->editor;
	}
	return() if not defined $editor;
	$self->{main_thread_only}->{on_finish} = $on_finish if $on_finish;
	$self->{main_thread_only}->{editor} = $editor;
	return $self;
}

sub run {
	my $self = shift;
	return 1;
}

sub prepare {
	my $self = shift;
	unless ( defined $self->{text} ) {
		require Carp;
		Carp::croak("Could not find the document's text.");
	}
	unless ( defined $self->{main_thread_only}->{editor} ) {
		require Carp;
		Carp::croak("Could not find the reference to the notebook page for GUI updating.");
	}
	return 1;
}

sub finish {
	my $self     = shift;
	my $callback = $self->{main_thread_only}->{on_finish};
	if ( _CODE($callback) ) {
		$callback->($self);
	} else {
		$self->update_gui;
	}
}

sub update_gui {
	# TODO This and the helper routines used here probably need to be
	# document type specific (pragmata, modules and methods do 
	# not apply to all languages and there may be other hierarchy
	# levels instead)

	my $self    = shift;
	my $outline = $self->{outline};
	my $outlinebar = Padre->ide->wx->main->outline;
	my $editor  = $self->{main_thread_only}->{editor};

	# Clear out the existing stuff
	$outlinebar->clear;

	require Padre::Wx;
	# If there are no errors, clear the outline pane and return.
	unless ( $outline ) {
		return;
	}

	# Again, slightly differently
	unless ( @$outline ) {
		return 1;
	}

	# Update the outline pane
	if( scalar(@{ $outline }) == 1 ) {
		my $pkg = $outline->[0];
		my $root = $outlinebar->AddRoot(
			$pkg->{name},
			-1,
			-1,
			Wx::TreeItemData->new( {
				line => $pkg->{line},
				name => $pkg->{name}
			} )
		);
		foreach my $type ( qw(pragmata modules methods) ) {
			$self->add_subtree( $outlinebar, $pkg, $type, $root );
		}
	} else {
		my $root = $outlinebar->AddRoot(
			Wx::gettext('Outline'),
			-1,
			-1,
			Wx::TreeItemData->new('')
		);
		foreach my $pkg ( @{ $outline } ) {
			my $branch = $outlinebar->AppendItem(
				$root,
				$pkg->{name},
				-1,
				-1,
				Wx::TreeItemData->new( {
					line => $pkg->{line},
					name => $pkg->{name}
				} )
			);
			foreach my $type ( qw(pragmata modules methods) ) {
				$self->add_subtree( $outlinebar, $pkg, $type, $branch );
			}
		}
	}
	$outlinebar->ExpandAll;
	$outlinebar->GetBestSize;

	return 1;
}

sub add_subtree {
	my ( $self, $outlinebar, $pkg, $type, $root ) = @_;

	if ( defined($pkg->{$type}) && scalar(@{ $pkg->{$type} }) > 0 ) {
		my $type_elem = $outlinebar->AppendItem(
			$root,
			ucfirst($type),
			-1,
			-1,
			Wx::TreeItemData->new()
		);
		foreach my $item ( sort { $a->{name} cmp $b->{name} } @{ $pkg->{$type} } ) {
			$self->append_entry($outlinebar, $type_elem, $item);
		}
	}
	return;
}

sub append_entry {
	my ( $self, $outlinebar, $parent, $item ) = @_;
	$outlinebar->AppendItem(
		$parent,
		$item->{name},
		-1,
		-1,
		Wx::TreeItemData->new( {
			line => $item->{line},
			name => $item->{name}
		} )
	);
	return;
}


1;

__END__

=head1 SEE ALSO

This class inherits from C<Padre::Task> and its instances can be scheduled
using C<Padre::TaskManager>.

The transfer of the objects to and from the worker threads is implemented
with L<Storable>.

=head1 AUTHOR

 Steffen Mueller C<smueller@cpan.org>
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
