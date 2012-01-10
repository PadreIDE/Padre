package [% module %];

=pod

=head1 NAME

[% module %] - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = [% module %]->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=cut

use 5.010;
use strict;
use warnings;

our $VERSION = '0.01';

=pod

=head2 new

  my $object = [% module %]->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<[% module %]> object.

So no big surprises there...

Returns a new B<[% module %]> or dies on error.

=cut

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	return $self;
}

=pod

=head2 dummy

This method does something... apparently.

=cut

sub dummy {
	my $self = shift;

	# Do something here

	return 1;
}

1;

=pod

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2012
[%- IF config.identity_name -%]
 [% config.identity_name %]
[%- ELSE -%]
 Anonymous
[%- END %].

=cut
