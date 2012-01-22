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

C<Padre::Pod2HTML> provides a central point for L<pod2html> functionality inside
of Padre.

Initially it just provides an internal convenience that converts
L<Pod::Simple::XHTML> from printing to C<STDOUT> to capturing the HTML.

Currently the constructor does not take any options.

=cut

use 5.008;
use strict;
use warnings;
use Pod::Simple::XHTML ();

our $VERSION = '0.94';
our @ISA     = 'Pod::Simple::XHTML';





#####################################################################
# One-Shot Methods

sub file2html {
	my $class = shift;
	my $file  = shift;
	my $self  = $class->new(@_);

	# Generate the HTML
	$self->{html} = '';
	$self->parse_file($file);
	$self->clean_html;

	return $self->{html};
}

sub pod2html {
	my $class = shift;
	my $input = shift;
	my $self  = $class->new(@_);

	# Generate the HTML
	$self->{html} = '';
	$self->parse_string_document($input);
	$self->clean_html;

	return $self->{html};
}





#####################################################################
# Capture instead of print

# Prevent binding to STDOUT
sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Ignore POD irregularities
	$self->no_whining(1);
	$self->no_errata_section(1);
	$self->output_string( \$self->{html} );

	return $self;
}

sub clean_html {
	my $self = shift;
	return unless defined $self->{html};

	#FIX ME: this takes care of a bug in Pod::Simple::XHTML
	$self->{html} =~ s/<</&lt&lt;/g;
	$self->{html} =~ s/< /&lt /g;
	$self->{html} =~ s/<=/&lt=/g;

	#FIX ME: this is incredibly bad, but the anchors are predictible
	$self->{html} =~ s/<a href=".*?">|<\/a>//g;

	return 1;
}

1;

=pod

=head1 AUTHOR

Adam Kennedy C<adamk@cpan.org>

Ahmad M. Zawawi C<ahmad.zawawi@gmail.com>

=head1 SEE ALSO

L<Padre>

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
