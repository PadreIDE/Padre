package Padre::Wx::Frame::POD;

=pod

=head1 NAME

Padre::Wx::Frame::POD - Simple Single-Document Pod2HTML Viewer

=head1 SYNOPSIS

  # Create the Pod viewing window
  my $frame = Padre::Wx::Frame::POD->new;

  # Load a document with POD in it
  $frame->load_file('file.pod');

=head1 DESCRIPTION

C<Padre::Wx::Frame::POD> provides a simple standalone window containing a
Pod2HTML rendering widget, for displaying a single POD document as
HTML.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::HtmlWindow ();
use Padre::Wx::FBP::POD   ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::FBP::POD';

=pod

=head2 new

The C<new> constructor creates a new, empty, frame for displaying Pod.

=head2 load_file

  $frame->load_file( 'filename.pod' );

The C<load_file> method loads a named file into the POD viewer.

=cut

sub load_file {
	my $self = shift;
	$self->{html}->background_file(@_);
}

1;

=pod

=head1 SUPPORT

See the main L<Padre> documentation.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
