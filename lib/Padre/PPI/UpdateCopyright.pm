package Padre::PPI::UpdateCopyright;

=pod

=head1 NAME

Padre::PPI::UpdateCopyright - Demonstration transform

=head1 SYNOPSIS

  my $transform = Padre::PPI::UpdateCopyright->new(
      name => 'Adam Kennedy'
  );
  $transform->apply( Padre::Current->document );

=head1 DESCRIPTION

C<Padre::PPI::UpdateCopyright> provides a demonstration of a typical
L<Padre::Transform> class.

This class implements a document transform that will take the name of an
author and update the copyright statement to refer to the current year,
if it does not already do so.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Params::Util          ();
use Padre::Current        ();
use Padre::PPI::Transform ();

our $VERSION = '1.02';
our @ISA     = 'Padre::PPI::Transform';





#####################################################################
# Constructor and Accessors

=pod

=head2 new

  my $transform = Padre::PPI::UpdateCopyright->new(
      name => 'Adam Kennedy'
  );

The C<new> constructor creates a new transform object for a specific
author. It takes a single C<name> parameter that should be the name
(or longer string) for the author.

Specifying the name is required to allow the changing of a subset of
copyright statements that refer to you from a larger set in a file.

=cut

sub new {
	my $self = shift->SUPER::new(@_);

	# We need a name
	unless ( defined Params::Util::_STRING( $self->name ) ) {

		# Try to pull a name from your config
		$self->{name} = Padre::Current->config->identity_name;
	}
	unless ( defined Params::Util::_STRING( $self->name ) ) {
		die 'Did not provide a valid name param';
	}

	return $self;
}

=pod

=head2 name

The C<name> accessor returns the author name that the transform will be
searching for copyright statements of.

=cut

sub name {
	$_[0]->{name};
}





#####################################################################
# Transform Methods

sub document {
	my $self = shift;
	my $document = Params::Util::_INSTANCE( shift, 'PPI::Document' ) or return;

	# Find things to transform
	my $name     = quotemeta $self->name;
	my $regexp   = qr/\bcopyright\b.*$name/mi;
	my $elements = $document->find(
		sub {
			$_[1]->isa('PPI::Token::Pod') or return '';
			$_[1]->content =~ $regexp or return '';
			return 1;
		}
	);
	return   unless defined $elements;
	return 0 unless $elements;

	# Try to transform any elements
	my $changes = 0;
	my $change  = sub {
		my $copyright = shift;
		my $thisyear  = ( localtime time )[5] + 1900;
		my @year      = $copyright =~ m/(\d{4})/g;

		if ( @year == 1 ) {

			# Handle the single year format
			if ( $year[0] == $thisyear ) {

				# No change
				return $copyright;
			} else {

				# Convert from single year to multiple year
				$changes++;
				$copyright =~ s/(\d{4})/$1 - $thisyear/;
				return $copyright;
			}
		}

		if ( @year == 2 ) {

			# Handle the range format
			if ( $year[1] == $thisyear ) {

				# No change
				return $copyright;
			} else {

				# Change the second year to the current one
				$changes++;
				$copyright =~ s/$year[1]/$thisyear/;
				return $copyright;
			}
		}

		# Huh?
		die "Invalid or unknown copyright line '$copyright'";
	};

	# Attempt to transform each element
	my $pattern = qr/\b(copyright.*?)((?:\d{4}\s*-\s*)?\d{4})(.*$name)/mi;
	foreach my $element (@$elements) {
		$element->{content} =~ s/$pattern/$1 . $change->($2) . $3/eg;
	}

	return $changes;
}

1;

=pod

=head1 TO DO

May need to overload some methods to forcefully prevent Document
objects becoming children of another Node.

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2009-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
