package [% util.new_modulename %];

=pod

=head1 NAME

[% util.new_modulename %] - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = [% util.new_modulename %]->new(
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

  my $object = [% util.new_modulename %]->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<[% util.new_modulename %]> object.

So no big surprises there...

Returns a new B<[% util.new_modulename %]> or dies on error.

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

Copyright 2011
[%- IF config.identity_name -%]
 [% config.identity_name %]
[%- ELSE -%]
 Anonymous
[%- END %].

=cut
