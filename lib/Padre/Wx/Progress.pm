package Padre::Wx::Progress;

=pod

=head1 NAME

Padre::Wx::Progress - Tell the user that we're doing something

=head1 SYNOPSIS

  my $object = Padre::Wx::Progress->new($title, $max_count,
               [modal => 1,]
               [lazy  => 1,]
               );
  
  $object->Update($done_count, $current_work_text);

=head1 DESCRIPTION

Shows a progress bar dialog to tell the user that we're doing something.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use Padre::Wx;

our $VERSION = '0.01';

=pod

=head2 new

  my $object = Padre::Wx::Progress->new($title, $max_count,
               [message => $default_message]
               [modal => 1,]
               [lazy  => 1,]
               );

The C<new> constructor lets you create a new B<Padre::Wx::Progress> object.

$title is the title of the new box.

$max_count contains the highest item-number being processed.

Options:

A default message could be set (in case ->update should be called without text)
with the message key. This is overriden by the newest ->update - text.

Set modal to true to lock other application windows while the progress
box is displayed

Set lazy to true to show the progress dialog only if the whole process
takes long enough that the progress box makes sense.

Returns a new B<Padre::Wx::Progress> or dies on error.

=cut

sub new {
	my $class = shift;

	my $main  = shift;
	my $title = shift;
	my $max   = shift;

	my $self = bless { max => $max, title => $title, main => $main, start => time, @_ }, $class;

	$self->_create_progress if !$self->{lazy};
	return $self;
}

sub _create_progress {
	my $self = shift;

	my $flags = Wx::wxPD_ELAPSED_TIME | Wx::wxPD_ESTIMATED_TIME | Wx::wxPD_REMAINING_TIME | Wx::wxPD_AUTO_HIDE;
	$flags |= Wx::wxPD_APP_MODAL if $self->{modal};

	$self->{dialog} = Wx::ProgressDialog->new( $self->{title}, 'text1', $self->{max}, $self->{main}, $flags );
}

=pod

=head2 update

  $progress->update($value,[$text])

Updates the progress bar.

=cut

sub update {
	my $self  = shift;
	my $value = shift;
	my $text  = shift;

	if ( !defined( $self->{dialog} ) ) {

		# Lazy mode: Don't waste CPU time for a box which is destroyed immed.
		return 1 if $self->{start} >= ( time - 1 );
		$self->_create_progress;
	}

	$self->{dialog}->Update( $value, $text );

	return 1;
}

sub Destroy {
	shift->DESTROY;
}

sub DESTROY {
	my $self = shift;
	$self->{dialog}->Destroy if defined( $self->{dialog} );
}

1;

=pod

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2008 Anonymous.

=cut
