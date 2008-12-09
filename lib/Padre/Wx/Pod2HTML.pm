package Padre::Wx::HtmlWindow;

=pod

=head1 NAME

Padre::Wx::HtmlWindow - An extended Wx::HtmlWindow that supports POD to HTML

=head1 DESCRIPTION

This class is intended to implement a HTML viewer that internally renders the
HTML from standalone or embedded POD.

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx ();
use Wx::Html  ();

our $VERSION = '0.20';
our @ISA     = 'Wx::HtmlWindow';





#####################################################################
# Loader Methods

sub load_file {
	my $self = shift;
	my $file = shift;
	my $pod;
	SCOPE: {
		local */;
		local *FILE;
		open( FILE, '<', $file ) or die "Failed to open file";
		$pod = <FILE>;
		close( FILE )            or die "Failed to close file";
	}
	return $self->load_pod( $pod );
}

sub load_pod {
	my $self = shift;
	require Padre::Pod2HTML;
	$self->SetPage(
		Padre::Pod2HTML->pod2html($_[0])
	);
	return 1;
}

1;

=pod

=head1 SUPPORT

See the main L<Padre> documentation.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2008 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
