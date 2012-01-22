package Padre::Wx::Progress;

=pod

=head1 NAME

Padre::Wx::Progress - Tell the user that we're doing something

=head1 SYNOPSIS

  my $object = Padre::Wx::Progress->new($title, $max_count,
               modal => 1,
               lazy  => 1,
               );

  $object->Update($done_count, $current_work_text);

=head1 DESCRIPTION

Shows a progress bar dialog to tell the user that we're doing something.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Time::HiRes ();
use Padre::Wx ();

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';

=pod

=head2 new

    my $object = Padre::Wx::Progress->new(
        $title,
        $max_count,
        message => $default_message # optional
        modal => 1,                 # optional
        lazy  => 1,                 # optional
    );

The C<new> constructor lets you create a new C<Padre::Wx::Progress> object.

C<$title> is the title of the new box.

C<$max_count> contains the highest item-number being processed.

Options:

A default message could be set (in case C<update> should be called without text)
with the message key. This is overridden by the newest C<update> text.
Default is an empty message.

Set modal to true to lock other application windows while the progress
box is displayed. Default is 0 (non-modal).

Set lazy to true to show the progress dialog only if the whole process
takes long enough that the progress box makes sense. Default if 1 (lazy-mode).

All options are optional, Padre will use fixed defaults if they're missing.

Returns a new C<Padre::Wx::Progress> or dies on error.

=cut

sub new {
	my $class = shift;
	my $main  = shift;
	my $title = shift;
	my $max   = shift;

	my $self = bless {
		max   => $max,
		title => $title,
		main  => $main,
		start => Time::HiRes::time(),
		@_,
	}, $class;

	$self->{title}   ||= Wx::gettext('Please wait...');
	$self->{message} ||= '';

	# Lazy mode:
	# Create the progress bar only when it makes sense.
	# If this is requested don't create it here:
	$self->dialog unless $self->{lazy};

	return $self;
}

sub dialog {
	my $self = shift;
	unless ( defined $self->{dialog} ) {
		# Don't display if inside the lazy window
		if ( Time::HiRes::time() - $self->{start} < 1 ) {
			return;
		}

		# Default flags
		my $flags = Wx::PD_ELAPSED_TIME
			  | Wx::PD_ESTIMATED_TIME
			  | Wx::PD_REMAINING_TIME
			  | Wx::PD_AUTO_HIDE;
		if ( $self->{modal} ) {
			$flags |= Wx::PD_APP_MODAL;
		}

		# Create the Wx object
		$self->{dialog} = Wx::ProgressDialog->new(
			$self->{title},
			$self->{message},
			$self->{max},
			$self->{main},
			$flags,
		);
	}
	$self->{dialog};
}

=pod

=head2 update

    $progress->update( $value, $text );

Updates the progress bar with a new value and optional with a new text message.

The last message will stay if no new text is specified.

=cut

sub update {
	my $self   = shift;
	my $dialog = $self->dialog or return 1;
	$dialog->Update(@_);
}

# Simulate Wx destroy call
sub Destroy {
	if ( defined $_[0]->{dialog} ) {
		$_[0]->{dialog}->Hide;
		$_[0]->{dialog}->Destroy;
		delete $_[0]->{dialog};
	}
}

sub DESTROY {
	if ( defined $_[0]->{dialog} ) {
		$_[0]->{dialog}->Hide;
		$_[0]->{dialog}->Destroy;
		delete $_[0]->{dialog};
	}
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
