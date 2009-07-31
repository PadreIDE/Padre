package Padre::Pod2HTML;

=pod

=head1 NAME

Padre::Pod2HTML - A customised Pod to HTML for Padre

=head1 SYNOPSIS

  # The quicker way
  $html = Padre::Pod2HTML->pod2html( $pod_string );
  
  # The slower way
  $parser = Padre::Pod2HTML->new;
  $parser->parse_string_document( $pod_string );
  $html = $parser->html;

=head1 DESCRIPTION

Padre::Pod2HTML provides a central point for pod2html functionality inside
of Padre.

Inititally it just provides an internal convenience that converts
L<Pod::Simple::XHTML> from printing to STDOUT to capturing the HTML.

Currently the constructor does not take any options.

=cut

use 5.008;
use strict;
use warnings;
use Pod::Simple::XHTML ();

our $VERSION = '0.42';
our @ISA     = 'Pod::Simple::XHTML';

use Class::XSAccessor getters => {
	html => 'scratch', # Method to fetch out the scratch
};

#####################################################################
# One-Shot Method

sub pod2html {
	my $class = shift;
	my $input = shift;
	my $self  = $class->new(@_);
	$self->parse_string_document($input);
	return $self->html;
}

#####################################################################
# Capture instead of print

# Prevent binding to STDOUT
sub new {
	my $class = shift;
	my $self = $class->SUPER::new( output_fh => 1, @_ );

	# Ignore POD irregularities
	$self->no_whining(1);
	$self->no_errata_section(1);

	return $self;
}

# Disable emit so we build up a giant scratch variable
sub emit {
	return;
}

#####################################################################
# Customize HTML generation

1;

=pod

=head1 AUTHOR

Adam Kennedy C<adamk@cpan.org>

=head1 SEE ALSO

L<Padre>

=head1 COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
