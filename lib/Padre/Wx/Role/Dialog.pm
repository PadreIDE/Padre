package Padre::Wx::Role::Dialog;

=pod

=head1 NAME

Padre::Wx::Role::Dialog - Allow dialogs or frames to host simple common dialogs

=head1 SYNOPSIS

  package MyDialog;
  
  use Padre::Wx               ();
  use Padre::Wx::Role::Dialog ();
  
  @ISA = qw{
      Padre::Wx::Role::Dialog
      Wx::Dialog
  };
  
  # ...
  
  sub foo {
      my $self = shift;
  
      # Say something
      $self->message("Hello World!");
  
      return 1;
  }

=head1 DESCRIPTION

In a large Wx application with multiple dialogs or windows, many different
parts of the application may want to post messages or prompt the user.

The C<Padre::Wx::Role::Dialog> role allows dialog or window classes to
"host" these messages.

Providing these as a role means that each part of your application can post
messages and have the positioning of the dialogs be made appropriate for
each dialog.

=head1 METHODS

=cut

use 5.008005;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.94';

=pod

=head2 C<message>

  $parent->message( $text, $title );

Open a dialog box with C<$text> as the main text and C<$title> (title
defaults to C<Message>). There's only one OK button. No return value.

=cut

sub message {
	my $self    = shift;
	my $message = shift;
	my $title   = shift || Wx::gettext('Message');
	Wx::MessageBox(
		$message,
		$title,
		Wx::OK | Wx::CENTRE,
		$self,
	);
	return;
}

=pod

=head3 C<error>

  $parent->error( $text );

Open an error dialog box with C<$text> as main text. There's only one OK
button. No return value.

=cut

sub error {
	my $self = shift;
	my $message = shift || Wx::gettext('Unknown error from ') . caller;
	Wx::MessageBox(
		$message,
		Wx::gettext('Error'),
		Wx::OK | Wx::CENTRE | Wx::ICON_HAND,
		$self,
	);
	return;
}

=pod

=head3 C<password>

  my $password = $parent->password( $message, $title );

Generate a standard L<Wx> password dialog, using the internal
L<Wx::PasswordEntryDialog> class.

=cut

sub password {
	my $self   = shift;
	my $dialog = Wx::PasswordEntryDialog->new( $self, @_ );
	my $result = undef;
	$dialog->CenterOnParent;
	unless ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		$result = $dialog->GetValue;
	}
	$dialog->Destroy;
	return $result;
}

=pod

=head3 C<yes_no>

  my $boolean = $parent->yes_no(
      $message,
      $title,
  );

Generates a standard L<Wx> Yes/No dialog.

=cut

sub yes_no {
	my $self    = shift;
	my $message = shift;
	my $title   = shift || Wx::gettext('Message');
	my $dialog  = Wx::MessageDialog->new(
		$self,
		$message,
		$title,
		Wx::YES_NO | Wx::YES_DEFAULT | Wx::ICON_QUESTION,
	);
	$dialog->CenterOnParent;
	my $result = ( $dialog->ShowModal == Wx::ID_YES ) ? 1 : 0;
	$dialog->Destroy;
	return $result;
}

=pod

=head3 C<single_choice>

  my $choice = $parent->single_choice(
      $message,
      $title,
      [
          'Option One',
          'Option Two',
          'Option Three',
      ],
  );

Generates a standard L<Wx> single-choice dialog, using the standard
internal L<Wx::SingleChoiceDialog> class.

Returns the selected string, or C<undef> if the user selects C<Cancel>.

=cut

sub single_choice {
	my $self   = shift;
	my $dialog = Wx::SingleChoiceDialog->new( $self, @_ );
	my $result = undef;
	$dialog->CenterOnParent;
	unless ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		$result = $_[2]->[ $dialog->GetSelection ];
	}
	$dialog->Destroy;
	return $result;
}

=pod

=head3 C<multi_choice>

  my @choices = $parent->multi_choice(
      $message,
      $title,
      [
          'Option One',
          'Option Two',
          'Option Three',
      ],
  );

Generates a standard L<Wx> multi-choice dialog, using the internal
L<Wx::MultiChoiceDialog> class.

=cut

sub multi_choice {
	my $self   = shift;
	my $dialog = Wx::MultiChoiceDialog->new( $self, @_ );
	my @result = ();
	$dialog->CenterOnParent;
	unless ( $dialog->ShowModal == Wx::ID_CANCEL ) {
		@result = map { $_[2]->[$_] } $dialog->GetSelections;
	}
	$dialog->Destroy;
	return @result;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
