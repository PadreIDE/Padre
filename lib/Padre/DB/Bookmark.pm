package Padre::DB::Bookmark;

use strict;
use warnings;

our $VERSION = '0.42';

sub select_names {
	Padre::DB->selectcol_arrayref('select name from bookmark order by name');
}

# Finds and returns a single element by name
sub fetch_name {
	return ( $_[0]->select( 'where name = ?', $_[1] ) )[0];
}

1;

__END__

=pod

=head1 NAME

Padre::DB::Bookmark - Padre::DB class for the bookmark table

=head1 SYNOPSIS

  TO BE COMPLETED

=head1 DESCRIPTION

TO BE COMPLETED

=head1 METHODS

=head2 select

  # Get all objects in list context
  my @list = Padre::DB::Bookmark->select;
  
  # Get a subset of objects in scalar context
  my $array_ref = Padre::DB::Bookmark->select(
      'where name > ? order by name',
      1000,
  );

The C<select> method executes a typical SQL C<SELECT> query on the
bookmark table.

It takes an optional argument of a SQL phrase to be added after the
C<FROM bookmark> section of the query, followed by variables
to be bound to the placeholders in the SQL phrase. Any SQL that is
compatible with SQLite can be used in the parameter.

Returns a list of B<Padre::DB::Bookmark> objects when called in list context, or a
reference to an ARRAY of B<Padre::DB::Bookmark> objects when called in scalar context.

Throws an exception on error, typically directly from the L<DBI> layer.

=head2 count

  # How many objects are in the table
  my $rows = Padre::DB::Bookmark->count;
  
  # How many objects 
  my $small = Padre::DB::Bookmark->count(
      'where name > ?',
      1000,
  );

The C<count> method executes a C<SELECT COUNT(*)> query on the
bookmark table.

It takes an optional argument of a SQL phrase to be added after the
C<FROM bookmark> section of the query, followed by variables
to be bound to the placeholders in the SQL phrase. Any SQL that is
compatible with SQLite can be used in the parameter.

Returns the number of objects that match the condition.

Throws an exception on error, typically directly from the L<DBI> layer.

=head2 new

  TO BE COMPLETED

The C<new> constructor is used to create a new abstract object that
is not (yet) written to the database.

Returns a new L<Padre::DB::Bookmark> object.

=head2 create

  my $object = Padre::DB::Bookmark->create(

      name => 'value',

      file => 'value',

      line => 'value',

  );

The C<create> constructor is a one-step combination of C<new> and
C<insert> that takes the column parameters, creates a new
L<Padre::DB::Bookmark> object, inserts the appropriate row into the L<bookmark>
table, and then returns the object.

If the primary key column C<name> is not provided to the
constructor (or it is false) the object returned will have
C<name> set to the new unique identifier.
 
Returns a new L<bookmark> object, or throws an exception on error,
typically from the L<DBI> layer.

=head2 insert

  $object->insert;

The C<insert> method commits a new object (created with the C<new> method)
into the database.

If a the primary key column C<name> is not provided to the
constructor (or it is false) the object returned will have
C<name> set to the new unique identifier.

Returns the object itself as a convenience, or throws an exception
on error, typically from the L<DBI> layer.

=head2 delete

  # Delete a single instantiated object
  $object->delete;
  
  # Delete multiple rows from the bookmark table
  Padre::DB::Bookmark->delete('where name > ?', 1000);

The C<delete> method can be used in a class form and an instance form.

When used on an existing B<Padre::DB::Bookmark> instance, the C<delete> method
removes that specific instance from the C<bookmark>, leaving
the object ntact for you to deal with post-delete actions as you wish.

When used as a class method, it takes a compulsory argument of a SQL
phrase to be added after the C<DELETE FROM bookmark> section
of the query, followed by variables to be bound to the placeholders
in the SQL phrase. Any SQL that is compatible with SQLite can be used
in the parameter.

Returns true on success or throws an exception on error, or if you
attempt to call delete without a SQL condition phrase.

=head2 truncate

  # Delete all records in the bookmark table
  Padre::DB::Bookmark->truncate;

To prevent the common and extremely dangerous error case where
deletion is called accidentally without providing a condition,
the use of the C<delete> method without a specific condition
is forbidden.

Instead, the distinct method C<truncate> is provided to delete
all records in a table with specific intent.

Returns true, or throws an exception on error.

=head1 ACCESSORS

=head2 name

  if ( $object->name ) {
      print "Object has been inserted\n";
  } else {
      print "Object has not been inserted\n";
  }

Returns true, or throws an exception on error.


REMAINING ACCESSORS TO BE COMPLETED

=head1 SQL

The bookmark table was originally created with the
following SQL command.

  CREATE TABLE bookmark (
  	name VARCHAR(255) NOT NULL PRIMARY KEY,
  	file VARCHAR(255) NOT NULL,
  	line INTEGER NOT NULL
  )

=head1 SUPPORT

Padre::DB::Bookmark is part of the L<Padre::DB> API.

See the documentation for L<Padre::DB> for more information.

=head1 AUTHOR

Adam Kennedy

=head1 COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
