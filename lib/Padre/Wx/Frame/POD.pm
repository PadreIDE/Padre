package Padre::Wx::Frame::POD;

=pod

=head1 NAME

Padre::Wx::Frame::POD - Simple Single-Document Pod2HTML Viewer

=head1 SYNOPSIS

  # Create the Pod viewing window
  my $frame = Padre::Wx::Frame::POD->new;

  # Load a Pod file or document
  $frame->load_file( 'file.pod' );
  $frame->load_pod( "=head1 THIS IS POD!" );

=head1 DESCRIPTION

C<Padre::Wx::Frame::POD> provides a simple standalone window containing a
Pod2HTML rendering widget, for displaying a single POD document as
HTML.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.90';
our @ISA     = 'Wx::Frame';

=pod

=head2 new

The C<new> constructor creates a new, empty, frame for displaying Pod.

=cut

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(
		undef,
		-1,
		'POD Viewer',
		Wx::wxDefaultPosition,
		[ 500, 500 ],
	);

	# Create the panel within the frame
	$self->{panel} = Wx::Panel->new( $self, -1 );

	# Create the HTML widget within the panel
	require Padre::Wx::HtmlWindow;
	$self->{html} = Padre::Wx::HtmlWindow->new( $self->{panel}, -1 );

	return $self;
}

=pod

=head2 load_file

  $frame->load_file( 'filename.pod' );

The C<load_file> method loads a named file into the POD viewer.

=cut

sub load_file {
	my $self = shift;
	$self->{html}->load_file(@_);
}

=pod

=head2 load_pod

  $frame->load_pod( $pod_string );

The C<load_pod> method loads a document into the POD viewer by providing
the entire document as a string.

=cut

sub load_pod {
	my $self = shift;
	$self->{html}->load_pod(@_);
}

1;

=pod

=head1 SUPPORT

See the main L<Padre> documentation.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
